# AVIO

import Base: read, read!, show, close, eof, isopen, seek, seekstart

export read, read!, pump, openvideo, opencamera, playvideo, viewcam, play

using Compat

type StreamInfo
    stream_index0::Int             # zero-based
    stream::AVStream
    codec_ctx::AVCodecContext
end

abstract StreamContext

const EightBitTypes = Union{UInt8, N0f8, Main.ColorTypes.RGB{N0f8}}
@compat const PermutedArray{T,N,perm,iperm,AA<:Array} = Base.PermutedDimsArrays.PermutedDimsArray{T,N,perm,iperm,AA}
@compat const VidArray{T,N} = Union{Array{T,N},PermutedArray{T,N}}

# TODO: move this to Base
Base.unsafe_convert{T}(::Type{Ptr{T}}, A::PermutedArray{T}) = Base.unsafe_convert(Ptr{T}, parent(A))

# An audio-visual input stream/file
type AVInput{I}
    io::I
    apFormatContext::Vector{Ptr{AVFormatContext}}
    apAVIOContext::Vector{Ptr{AVIOContext}}
    avio_ctx_buffer_size::UInt
    aPacket::Vector{AVPacket}           # Reusable packet

    unknown_info::Vector{StreamInfo}
    video_info::Vector{StreamInfo}
    audio_info::Vector{StreamInfo}
    data_info::Vector{StreamInfo}
    subtitle_info::Vector{StreamInfo}
    attachment_info::Vector{StreamInfo}

    listening::Set{Int}
    stream_contexts::Array{StreamContext}

    isopen::Bool
end


function show(io::IO, avin::AVInput)
    println(io, "AVInput(", avin.io, ", ...), with")
    (len = length(avin.video_info))      > 0 && println(io, "  $len video stream(s)")
    (len = length(avin.audio_info))      > 0 && println(io, "  $len audio stream(s)")
    (len = length(avin.data_info))       > 0 && println(io, "  $len data stream(s)")
    (len = length(avin.subtitle_info))   > 0 && println(io, "  $len subtitle stream(s)")
    (len = length(avin.attachment_info)) > 0 && println(io, "  $len attachment stream(s)")
    (len = length(avin.unknown_info))    > 0 && println(io, "  $len unknown stream(s)")
end

type VideoTranscodeContext
    transcode_context::Ptr{SwsContext}

    transcode_interp::Cint
    target_pix_fmt::Cint
    target_bits_per_pixel::Int
    width::Int
    height::Int

    target_buf::Array{UInt8,3}  # TODO: this needs to be more general
    aTargetVideoFrame::Vector{AVFrame}
    apTargetDataBuffers::Vector{Ptr{UInt8}}
    apTargetLineSizes::Vector{Cint}
end

const TRANSCODE = true
const NO_TRANSCODE = false

type VideoReader{transcode} <: StreamContext
    avin::AVInput
    stream_info::StreamInfo

    stream_index0::Int
    pVideoCodecContext::Ptr{AVCodecContext}
    pVideoCodec::Ptr{AVCodec}
    aVideoFrame::Vector{AVFrame}   # Reusable frame
    aFrameFinished::Vector{Int32}

    format::Cint
    width::Cint
    height::Cint
    framerate::Rational
    aspect_ratio::Rational

    frame_queue::Vector{Vector{UInt8}}
    transcodeContext::VideoTranscodeContext
end

show(io::IO, vr::VideoReader) = print(io, "VideoReader(...)")

# Pump input for data
function pump(c::AVInput)
    pFormatContext = c.apFormatContext[1]

    while true
        !c.isopen && break

        ret = Base.disable_sigint() do
            av_read_frame(pFormatContext, pointer(c.aPacket))
        end
        ret < 0 && break

        packet = c.aPacket[1]
        stream_index = packet.stream_index

        # If we're not listening to this stream, skip it
        if stream_index in c.listening
            # Decode the packet, and check if the frame is complete
            frameFinished = decode_packet(c.stream_contexts[stream_index+1], c.aPacket)
            av_free_packet(pointer(c.aPacket))

            # If the frame is complete, we're done
            frameFinished && return stream_index
        else
            av_free_packet(pointer(c.aPacket))
        end
    end

    return -1
end

pump(r::StreamContext) = pump(r.avin)

function _read_packet(pavin::Ptr{AVInput}, pbuf::Ptr{UInt8}, buf_size::Cint)
    avin = unsafe_pointer_to_objref(pavin)
    out = unsafe_wrap(Array, pbuf, (buf_size,))
    convert(Cint, readbytes!(avin.io, out))
end

const read_packet  =  cfunction(_read_packet, Cint, (Ptr{AVInput}, Ptr{UInt8}, Cint))


function open_avinput(avin::AVInput, io::IO, input_format=C_NULL)

    !isreadable(io) && error("IO not readable")

    # These allow control over how much of the stream to consume when
    # determining the stream type
    # TODO: Change these defaults if necessary, or allow user to set
    #av_opt_set(avin.apFormatContext[1], "probesize", "100000000", 0)
    #av_opt_set(avin.apFormatContext[1], "analyzeduration", "1000000", 0)

    # Allocate the io buffer used by AVIOContext
    # Must be done with av_malloc, because it could be reallocated
    if (avio_ctx_buffer = av_malloc(avin.avio_ctx_buffer_size)) == C_NULL
        error("unable to allocate AVIOContext buffer (out of memory)")
    end

    # Allocate AVIOContext
    if (avin.apAVIOContext[1] = avio_alloc_context(avio_ctx_buffer, avin.avio_ctx_buffer_size,
                                                   0, pointer_from_objref(avin),
                                                   read_packet, C_NULL, C_NULL)) == C_NULL
        abuffer = [avio_ctx_buffer]
        av_freep(abuffer)
        error("Unable to allocate AVIOContext (out of memory)")
    end

    # pFormatContext->pb = pAVIOContext
    av_setfield(avin.apFormatContext[1], :pb, avin.apAVIOContext[1])

    # "Open" the input
    if avformat_open_input(avin.apFormatContext, C_NULL, input_format, C_NULL) != 0
        error("Unable to open input")
    end

    nothing
end

function open_avinput(avin::AVInput, source::AbstractString, input_format=C_NULL)
    if avformat_open_input(avin.apFormatContext,
                           source,
                           input_format,
                           C_NULL)    != 0
        error("Could not open file $source")
    end

    nothing
end

function AVInput{T<:Union{IO, AbstractString}}(source::T, input_format=C_NULL; avio_ctx_buffer_size=65536)
    aPacket = [AVPacket()]
    apFormatContext = Ptr{AVFormatContext}[avformat_alloc_context()]
    apAVIOContext = Ptr{AVIOContext}[C_NULL]

    # Allocate this object (needed to pass into AVIOContext in open_avinput)
    avin = AVInput{T}(source, apFormatContext, apAVIOContext, avio_ctx_buffer_size,
                      aPacket, [StreamInfo[] for i=1:6]..., Set(Int[]), StreamContext[], false)

    # Make sure we deallocate everything on exit
    finalizer(avin, close)

    # Set up the format context and open the input, based on the type of source
    open_avinput(avin, source, input_format)
    avin.isopen = true

    # Get the stream information
    if avformat_find_stream_info(avin.apFormatContext[1], C_NULL) < 0
        error("Unable to find stream information")
    end

    # Load streams, codec_contexts
    formatContext = unsafe_load(avin.apFormatContext[1]);

    for i = 1:formatContext.nb_streams
        pStream = unsafe_load(formatContext.streams,i)
        stream = unsafe_load(pStream)
        codec_ctx = unsafe_load(stream.codec)
        codec_type = codec_ctx.codec_type

        stream_info = StreamInfo(i-1, stream, codec_ctx)

        if codec_type == AVMEDIA_TYPE_VIDEO
            push!(avin.video_info, stream_info)
        elseif codec_type == AVMEDIA_TYPE_AUDIO
            push!(avin.audio_info, stream_info)
        elseif codec_type == AVMEDIA_TYPE_DATA
            push!(avin.data_info, stream_info)
        elseif codec_type == AVMEDIA_TYPE_SUBTITLE
            push!(avin.subtitle_info, stream_info)
        elseif codec_type == AVMEDIA_TYPE_ATTACHMENT
            push!(avin.attachment_info, stream_info)
        elseif codec_type == AVMEDIA_TYPE_UNKNOWN
            push!(avin.unknown_info, stream_info)
        end
    end

    resize!(avin.stream_contexts, formatContext.nb_streams)

    avin
end


function VideoReader(avin::AVInput, video_stream=1;
                     transcode::Bool=true,
                     transcode_interpolation=SWS_BILINEAR,
                     target_format=AV_PIX_FMT_RGB24)

    1 <= video_stream <= length(avin.video_info) || error("video stream $video_stream not found")

    stream_info = avin.video_info[video_stream]

    # Get basic stream info
    pVideoCodecContext = stream_info.stream.codec
    codecContext = stream_info.codec_ctx

    width, height = codecContext.width, codecContext.height
    pix_fmt = codecContext.pix_fmt
    pix_fmt < 0 && error("Unknown pixel format")

    framerate = codecContext.time_base.den // codecContext.time_base.num

    aspect_num = codecContext.sample_aspect_ratio.num
    aspect_den = codecContext.sample_aspect_ratio.den
    aspect_ratio = (aspect_den == 0) ? 0 // 1 : aspect_num // aspect_den

    # Find the decoder for the video stream
    pVideoCodec = avcodec_find_decoder(codecContext.codec_id)
    pVideoCodec == C_NULL && error("Unsupported Video Codec")

    # Open the decoder
    avcodec_open2(pVideoCodecContext, pVideoCodec, C_NULL) < 0 && error("Could not open codec")

    aVideoFrame = [AVFrame()]
    aFrameFinished = Int32[0]

    aTargetVideoFrame = [AVFrame()]

    # Set up transcoding
    # TODO: this should be optional
    pFmtDesc = av_pix_fmt_desc_get(target_format)
    bits_per_pixel = av_get_bits_per_pixel(pFmtDesc)

    if transcode && bits_per_pixel % 8 != 0
        error("Unsupported format (bits_per_pixel = $bits_per_pixel)")
    end

    N = Int64(bits_per_pixel >> 3)
    target_buf = Array{UInt8}(bits_per_pixel>>3, width, height)

    sws_context = sws_getContext(width, height, pix_fmt,
                                 width, height, target_format,
                                 transcode_interpolation, C_NULL, C_NULL, C_NULL)

    avpicture_fill(pointer(aTargetVideoFrame), target_buf, target_format, width, height)
    apTargetDataBuffers = reinterpret(Ptr{UInt8}, [aTargetVideoFrame[1].data])
    apTargetLineSizes   = reinterpret(Cint,       [aTargetVideoFrame[1].linesize])

    transcodeContext = VideoTranscodeContext(sws_context,
                                             transcode_interpolation,
                                             target_format,
                                             bits_per_pixel,
                                             width,
                                             height,
                                             target_buf,
                                             aTargetVideoFrame,
                                             apTargetDataBuffers,
                                             apTargetLineSizes)

    vr = VideoReader{transcode}(avin,
                                stream_info,

                                stream_info.stream_index0,
                                pVideoCodecContext,
                                pVideoCodec,
                                aVideoFrame,
                                aFrameFinished,

                                pix_fmt,
                                width,
                                height,
                                framerate,
                                aspect_ratio,

                                Vector{UInt8}[],
                                transcodeContext)

    idx0 = stream_info.stream_index0
    push!(avin.listening, idx0)
    avin.stream_contexts[idx0+1] = vr

    vr
end

VideoReader{T<:Union{IO, AbstractString}}(s::T, args...; kwargs...) = VideoReader(AVInput(s), args...; kwargs... )

function decode_packet(r::VideoReader, aPacket)
    # Do we already have a complete frame that hasn't been consumed?
    if have_decoded_frame(r)
        apSourceDataBuffers = reinterpret(Ptr{UInt8}, [r.aVideoFrame[1].data])
        sz = avpicture_get_size(r.format, r.width, r.height)
        push!(r.frame_queue, copy(unsafe_wrap(Array, apSourceDataBuffers[1], sz)))
        reset_frame_flag!(r)
    end

    avcodec_decode_video2(r.pVideoCodecContext,
                          r.aVideoFrame,
                          r.aFrameFinished,
                          aPacket)

    return have_decoded_frame(r)
end

# Converts a grabbed frame to the correct format (RGB by default)
# TODO: type stability?
function retrieve(r::VideoReader{TRANSCODE}) # true=transcode

    while !have_frame(r)
        idx = pump(r.avin)
        idx == r.stream_index0 && break
        idx == -1 && throw(EOFError())
    end

    t = r.transcodeContext

    if t.target_bits_per_pixel % 8 != 0
        error("Unsupported video retrieval format.  Please allocate the buffer yourself and call retrieve!()")
    end

    if t.target_bits_per_pixel == 8
        buf = permuteddimsview(Matrix{Gray{N0f8}}(r.width, r.height), (2,1))
    else
        buf = permuteddimsview(Matrix{RGB{N0f8}}(r.width, r.height), (2,1))
    end

    retrieve!(r, buf)
end

function retrieve(r::VideoReader{NO_TRANSCODE}) # false=don't transcode
    while !have_frame(r)
        idx = pump(r.avin)
        idx == r.stream_index0 && break
        idx == -1 && throw(EOFError())
    end

    # TODO: set actual dimensions ?
    buf_sz = avpicture_get_size(r.format, r.width, r.height)
    buf = Array(UInt8, buf_sz)

    retrieve!(r, buf)
end

# Converts a grabbed frame to the correct format (RGB by default)
function retrieve!{T<:EightBitTypes}(r::VideoReader{TRANSCODE}, buf::VidArray{T})
    while !have_frame(r)
        idx = pump(r.avin)
        idx == r.stream_index0 && break
        idx == -1 && throw(EOFError())
    end

    if !bufsize_check(r, buf)
        error("Buffer is the wrong size")
    end

    t = r.transcodeContext

    # Set up target buffer
    if pointer(buf) != t.apTargetDataBuffers[1]
        avpicture_fill(pointer(t.aTargetVideoFrame),
                       buf,
                       t.target_pix_fmt,
                       r.width, r.height)
        t.apTargetDataBuffers = reinterpret(Ptr{UInt8}, [t.aTargetVideoFrame[1].data])
        t.apTargetLineSizes   = reinterpret(Cint,       [t.aTargetVideoFrame[1].linesize])

    end

    apSourceDataBuffers = isempty(r.frame_queue) ? reinterpret(Ptr{UInt8}, [r.aVideoFrame[1].data]) :
                                                   reinterpret(Ptr{UInt8}, [shift!(r.frame_queue)])
    apSourceLineSizes   = reinterpret(Cint, [r.aVideoFrame[1].linesize])

    Base.sigatomic_begin()
    sws_scale(t.transcode_context,
              apSourceDataBuffers,
              apSourceLineSizes,
              zero(Int32),
              r.height,
              t.apTargetDataBuffers,
              t.apTargetLineSizes)
    Base.sigatomic_end()

    reset_frame_flag!(r)

    return buf
end

function retrieve!{T<:EightBitTypes}(r::VideoReader{NO_TRANSCODE}, buf::VidArray{T})
    while !have_frame(r)
        idx = pump(r.avin)
        idx == r.stream_index0 && break
        idx == -1 && throw(EOFError())
    end

    if !bufsize_check(r, buf)
        error("Buffer is the wrong size")
    end
end

# Utility functions

# Not exported
open(filename::AbstractString) = AVInput(filename)
openvideo(args...; kwargs...) = VideoReader(args...; kwargs...)

read(r::VideoReader) = retrieve(r)
read!{T<:EightBitTypes}(r::VideoReader, buf::AbstractArray{T}) = retrieve!(r, buf)

isopen{I<:IO}(avin::AVInput{I}) = isopen(avin.io)
isopen(avin::AVInput) = avin.isopen
isopen(r::VideoReader) = isopen(r.avin)

bufsize_check{T<:EightBitTypes}(r::VideoReader{NO_TRANSCODE}, buf::VidArray{T}) = (length(buf)*sizeof(T) == avpicture_get_size(r.format, r.width, r.height))
bufsize_check{T<:EightBitTypes}(r::VideoReader{TRANSCODE}, buf::VidArray{T}) = bufsize_check(r.transcodeContext, buf)
bufsize_check{T<:EightBitTypes}(t::VideoTranscodeContext, buf::VidArray{T}) = (length(buf)*sizeof(T) == avpicture_get_size(t.target_pix_fmt, t.width, t.height))

have_decoded_frame(r) = r.aFrameFinished[1] > 0  # TODO: make sure the last frame was made available
have_frame(r::StreamContext) = !isempty(r.frame_queue) || have_decoded_frame(r)
have_frame(avin::AVInput) = any(Bool[have_frame(avin.stream_contexts[i+1]) for i in avin.listening])

reset_frame_flag!(r) = (r.aFrameFinished[1] = 0)

function seconds_to_timestamp(s::Float64, time_base::AVRational)
    return convert(Int64, floor(s *  convert(Float64, time_base.den) / convert(Float64, time_base.num)))
end

function seek(s::VideoReader, seconds::Float64,
              seconds_min::Float64 = -1.0,  seconds_max::Float64 = -1.0,
              video_stream::Int64=1, forward::Bool=false)
    !isopen(s) && throw(ErrorException("Video input stream is not open!"))

    fc = s.avin.apFormatContext[1]

    pCodecContext = s.pVideoCodecContext # AVCodecContext

    seek(s.avin, seconds, seconds_min, seconds_max, video_stream, forward)

    avcodec_flush_buffers(pCodecContext)

    stream = s.avin.video_info[video_stream].stream
    first_dts = stream.first_dts

    actualTimestamp = s.aVideoFrame[video_stream].pkt_dts   #av_frame_get_best_effort_timestamp(s.aVideoFrame)
    dts = first_dts + seconds_to_timestamp(seconds, stream.time_base)
    frameskip = convert(Int64,(stream.time_base.den/stream.time_base.num)/(stream.r_frame_rate.num/stream.r_frame_rate.den))

    while actualTimestamp < (dts - frameskip)
        while !have_frame(s)
            idx = pump(s.avin)
            idx == s.stream_index0 && break
            idx == -1 && throw(EOFError())
        end
        reset_frame_flag!(s)
        actualTimestamp = s.aVideoFrame[video_stream].pkt_dts   #av_frame_get_best_effort_timestamp(s.aVideoFrame)
    end
    return(s)
end

function seek{T<:AbstractString}(avin::AVInput{T}, seconds::Float64,
                                 seconds_min::Float64 = -1.0,  seconds_max::Float64 = -1.0,
                                 video_stream::Int64 = 1, forward::Bool=false)

    #Using 10 seconds before and after the desired timestamp, since the seek function
    #seek to the nearest keyframe, and 10 seconds is the longest GOP length seen in
    #practical usage.
    const max_interval = 10.0

    # AVFormatContext
    fc = avin.apFormatContext[1]

    # Get stream information
    stream_info = avin.video_info[video_stream]
    seek_stream_index = stream_info.stream_index0
    stream = stream_info.stream
    first_dts = stream.first_dts
    time_base = stream.time_base

    #Timestamp calculations
    if seconds_min < 0
        seconds_min = max(seconds - max_interval, 0.0)
    end

    if seconds_max < 0
        seconds_max = seconds + max_interval
    end

    dts = first_dts + seconds_to_timestamp(seconds, time_base)
    min_dts = first_dts + seconds_to_timestamp(seconds_min, time_base)
    #max_dts = first_dts + seconds_to_timestamp(seconds_max, time_base)

    flags = AVSEEK_FLAG_ANY
    if !forward
        flags = AVSEEK_FLAG_BACKWARD
    end

    # Seek
    ret = avformat_seek_file(fc, seek_stream_index, min_dts, dts, dts, flags)
    ret < 0 && throw(ErrorException("Could not seek in stream"))
    return avin
end

function seekstart(s::VideoReader, video_stream=1)
    return seek(s, 0.0, 0.0, 0.0, video_stream, false)
end

function seekstart{T<:AbstractString}(avin::AVInput{T}, video_stream = 1)
    return seek(avin, 0.0, 0.0, 0.0, video_stream, false)
end

## This doesn't work...
#seekstart{T<:IO}(avin::AVInput{T}, video_stream = 1) = seekstart(avin.io)
seekstart{T<:IO}(avin::AVInput{T}, video_stream = 1) = throw(ErrorException("Sorry, Seeking is not supported from IO streams"))


function eof(avin::AVInput)
    !isopen(avin) && return true
    have_frame(avin) && return false
    got_frame = (pump(avin) != -1)
    return !got_frame
end

function eof{I<:IO}(avin::AVInput{I})
    !isopen(avin) && return true
    have_frame(avin) && return false
    return eof(avin.io)
end

eof(r::VideoReader) = eof(r.avin)

close(r::VideoReader) = close(r.avin)
_close(r::VideoReader) = avcodec_close(r.pVideoCodecContext)

# Free AVIOContext object when done
function close(avin::AVInput)
    Base.sigatomic_begin()
    isopen = avin.isopen
    avin.isopen = false
    Base.sigatomic_end()

    !isopen && return

    for i in avin.listening
        _close(avin.stream_contexts[i+1])
    end

    # Fix for segmentation fault issue #44
    empty!(avin.listening)

    Base.sigatomic_begin()
    if avin.apFormatContext[1] != C_NULL
        avformat_close_input(avin.apFormatContext)
    end
    Base.sigatomic_end()

    Base.sigatomic_begin()
    if avin.apAVIOContext[1] != C_NULL
        p = av_pointer_to_field(avin.apAVIOContext[1], :buffer)
        p != C_NULL && av_freep(p)
        av_freep(avin.apAVIOContext)
    end
    Base.sigatomic_end()
end

# try
#     if isa(Main.ImageView, Module)
        # # Define read and retrieve for Images
        # global playvideo, viewcam, play

        # function play(f, flip=false)
        #     buf = read(f)
        #     ret = Main.ImageView.imshow(buf)
        #     canvas = ret["gui"]["canvas"]

        #     while !eof(f)
        #         read!(f, buf)
        #         Main.ImageView.imshow(canvas, buf)
        #         sleep(1/f.framerate)
        #     end
        # end

        # function playvideo(video)
        #     f = VideoIO.openvideo(video)
        #     play(f)
        # end

        # if have_avdevice()
        #     function viewcam(device=DEFAULT_CAMERA_DEVICE, format=DEFAULT_CAMERA_FORMAT)
        #         camera = opencamera(device, format)
        #         play(camera, true)
        #     end
        # else
        #     function viewcam()
        #         error("libavdevice not present")
        #     end
        # end
    # end
# catch
#     global playvideo, viewcam, play
#     no_imageview() = error("Please load ImageView before VideoIO to enable play(...), playvideo(...) and viewcam()")
#     play() = no_imageview()
#     playvideo() = no_imageview()
#     viewcam() = no_imageview()
# end


