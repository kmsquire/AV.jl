var documenterSearchIndex = {"docs":
[{"location":"#Introduction-1","page":"Introduction","title":"Introduction","text":"","category":"section"},{"location":"#","page":"Introduction","title":"Introduction","text":"This library provides methods for reading and writing video files.","category":"page"},{"location":"#","page":"Introduction","title":"Introduction","text":"Functionality is based on a dedicated build of ffmpeg 4.1, provided via FFMPEGBuilder","category":"page"},{"location":"#","page":"Introduction","title":"Introduction","text":"Explore the source at github.com/JuliaIO/VideoIO.jl","category":"page"},{"location":"#Platform-Nodes:-1","page":"Introduction","title":"Platform Nodes:","text":"","category":"section"},{"location":"#","page":"Introduction","title":"Introduction","text":"ARM: For truly lossless reading & writing, there is a known issue on ARM that results in small precision differences when reading/writing some video files. As such, tests for frame comparison are currently skipped on ARM. Issues/PRs welcome for helping to get this fixed.","category":"page"},{"location":"#Installation-1","page":"Introduction","title":"Installation","text":"","category":"section"},{"location":"#","page":"Introduction","title":"Introduction","text":"The package can be installed with the Julia package manager. From the Julia REPL, type ] to enter the Pkg REPL mode and run:","category":"page"},{"location":"#","page":"Introduction","title":"Introduction","text":"pkg> add VideoIO","category":"page"},{"location":"#","page":"Introduction","title":"Introduction","text":"Or, equivalently, via the Pkg API:","category":"page"},{"location":"#","page":"Introduction","title":"Introduction","text":"julia> import Pkg; Pkg.add(\"VideoIO\")","category":"page"},{"location":"reading/#Video-Reading-1","page":"Reading Videos","title":"Video Reading","text":"","category":"section"},{"location":"reading/#","page":"Reading Videos","title":"Reading Videos","text":"Note: Reading of audio streams is not yet implemented","category":"page"},{"location":"reading/#Reading-Video-Files-1","page":"Reading Videos","title":"Reading Video Files","text":"","category":"section"},{"location":"reading/#Direct-Video-Playback-1","page":"Reading Videos","title":"Direct Video Playback","text":"","category":"section"},{"location":"reading/#","page":"Reading Videos","title":"Reading Videos","text":"A trivial video player interface exists (no audio): Note: Makie must be imported first to enable playback functionality.","category":"page"},{"location":"reading/#","page":"Reading Videos","title":"Reading Videos","text":"using Makie\nusing VideoIO\n\nf = VideoIO.testvideo(\"annie_oakley\")  # downloaded if not available\nVideoIO.playvideo(f)  # no sound","category":"page"},{"location":"reading/#Custom-Frame-Reading-1","page":"Reading Videos","title":"Custom Frame Reading","text":"","category":"section"},{"location":"reading/#","page":"Reading Videos","title":"Reading Videos","text":"VideoIO contains a simple high-level interface which allows reading of video frames from a supported video file, or from a camera device:","category":"page"},{"location":"reading/#","page":"Reading Videos","title":"Reading Videos","text":"import Makie\nimport VideoIO\n\nio = VideoIO.open(video_file)\nf = VideoIO.openvideo(io)\n\n# One can seek to an arbitrary position in the video\nseek(f,2.5)  ## The second parameter is the time in seconds and must be Float64\nimg = read(f)\nscene = Makie.Scene(resolution = size(img))\nmakieimg = Makie.image!(scene, buf, show_axis = false, scale_plot = false)[end]\nMakie.rotate!(scene, -0.5pi)\ndisplay(scene)\n\nwhile !eof(f)\n    read!(f, img)\n    makieimg[1] = img\n    #sleep(1/30)\nend","category":"page"},{"location":"reading/#","page":"Reading Videos","title":"Reading Videos","text":"This code is essentially the code in playvideo, and will read and (without the sleep) play a movie file as fast as possible.","category":"page"},{"location":"reading/#","page":"Reading Videos","title":"Reading Videos","text":"As with the playvideo function, the Images and ImageView packages must be loaded for the appropriate functions to be available.","category":"page"},{"location":"reading/#","page":"Reading Videos","title":"Reading Videos","text":"As an additional handling example, here a grayscale video is read and parsed into a Vector(Array{UInt8}}","category":"page"},{"location":"reading/#","page":"Reading Videos","title":"Reading Videos","text":"f = VideoIO.openvideo(filename,target_format=VideoIO.AV_PIX_FMT_GRAY8)\nv = Vector{Array{UInt8}}(undef,0)\nwhile !eof(f)\n    push!(v,reinterpret(UInt8, read(f)))\nend\nclose(f)","category":"page"},{"location":"reading/#Reading-Camera-Output-1","page":"Reading Videos","title":"Reading Camera Output","text":"","category":"section"},{"location":"reading/#Direct-Camera-Playback-1","page":"Reading Videos","title":"Direct Camera Playback","text":"","category":"section"},{"location":"reading/#","page":"Reading Videos","title":"Reading Videos","text":"The default system webcam can be viewed directly","category":"page"},{"location":"reading/#","page":"Reading Videos","title":"Reading Videos","text":"using Makie\nusing VideoIO\nVideoIO.viewcam()","category":"page"},{"location":"reading/#","page":"Reading Videos","title":"Reading Videos","text":"Alternatively, frames can be read iteratively","category":"page"},{"location":"reading/#","page":"Reading Videos","title":"Reading Videos","text":"using VideoIO\ncam = VideoIO.opencamera()\nfor i in 1:100\n    img = read(cam)\n    sleep(1/framerate)\nend","category":"page"},{"location":"reading/#Video-Properties-and-Metadata-1","page":"Reading Videos","title":"Video Properties & Metadata","text":"","category":"section"},{"location":"reading/#","page":"Reading Videos","title":"Reading Videos","text":"VideoIO.get_start_time","category":"page"},{"location":"reading/#VideoIO.get_start_time","page":"Reading Videos","title":"VideoIO.get_start_time","text":"get_start_time(file::String) -> DateTime\n\nReturn the starting date & time of the video file. Note that if the starting date & time are missing, this function will return the Unix epoch (00:00 1st January 1970).\n\n\n\n\n\n","category":"function"},{"location":"reading/#","page":"Reading Videos","title":"Reading Videos","text":"VideoIO.get_time_duration","category":"page"},{"location":"reading/#VideoIO.get_time_duration","page":"Reading Videos","title":"VideoIO.get_time_duration","text":"get_time_duration(file::String) -> (DateTime, Microsecond)\n\nReturn the starting date & time as well as the duration of the video file. Note that if the starting date & time are missing, this function will return the Unix epoch (00:00 1st January 1970).\n\n\n\n\n\n","category":"function"},{"location":"reading/#","page":"Reading Videos","title":"Reading Videos","text":"VideoIO.get_duration","category":"page"},{"location":"reading/#VideoIO.get_duration","page":"Reading Videos","title":"VideoIO.get_duration","text":"get_duration(file::String) -> Float64\n\nReturn the duration of the video file in seconds (float).\n\n\n\n\n\n","category":"function"},{"location":"writing/#Writing-Videos-1","page":"Writing Videos","title":"Writing Videos","text":"","category":"section"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"Note: Writing of audio streams is not yet implemented","category":"page"},{"location":"writing/#Single-step-Encoding-1","page":"Writing Videos","title":"Single-step Encoding","text":"","category":"section"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"Videos can be encoded directly from image stack using encodevideo(filename::String,imgstack::Array) where imgstack is an array of image arrays with identical type and size.","category":"page"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"For instance, say an image stack has been constructed from reading a series of image files 1.png, 2.png,3.png etc. :","category":"page"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"imgnames = filter(x->occursin(\".png\",x),readdir()) # Populate list of all .pngs\nintstrings =  map(x->split(x,\".\")[1],imgnames) # Extract index from filenames\np = sortperm(parse.(Int,intstrings)) #sort files numerically\nimgstack = []\nfor imgname in imgnames[p]\n    push!(imgstack,read(imgname))\nend","category":"page"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"The entire image stack can be encoded in a single step:","category":"page"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"using VideoIO\nprops = [:priv_data => (\"crf\"=>\"22\",\"preset\"=>\"medium\")]\nencodevideo(\"video.mp4\",imgstack,framerate=30,AVCodecContextProperties=props)\n\n[ Info: Video file saved: /Users/username/Documents/video.mp4\n[ Info: frame=  100 fps=0.0 q=-1.0 Lsize=  129867kB time=00:00:03.23 bitrate=329035.1kbits/s speed=8.17x    \n[ Info: video:129865kB audio:0kB subtitle:0kB other streams:0kB global headers:0kB muxing overhead: 0.001692%","category":"page"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"VideoIO.encodevideo","category":"page"},{"location":"writing/#VideoIO.encodevideo","page":"Writing Videos","title":"VideoIO.encodevideo","text":"encodevideo(filename::String,imgstack::Array;     AVCodecContextProperties = AVCodecContextPropertiesDefault,     codec_name = \"libx264\",     framerate = 24)\n\nEncode image stack to video file\n\n\n\n\n\n","category":"function"},{"location":"writing/#Iterative-Encoding-1","page":"Writing Videos","title":"Iterative Encoding","text":"","category":"section"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"Alternatively, videos can be encoded iteratively within custom loops.  The encoding steps follow:","category":"page"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"Initialize encoder with prepareencoder\nIteratively add frames with appendencode\nEnd the encoding with finishencode\nMultiplex the stream into a video container with mux","category":"page"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"For instance:","category":"page"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"using VideoIO, ProgressMeter\n\nimgnames = filter(x->occursin(\".png\",x),readdir()) # Populate list of all .pngs\nintstrings =  map(x->split(x,\".\")[1],imgnames) # Extract index from filenames\np = sortperm(parse.(Int,intstrings)) #sort files numerically\nimgnames = imgnames[p]\n\nfilename = \"manual.mp4\"\nframerate = 24\nprops = [:priv_data => (\"crf\"=>\"22\",\"preset\"=>\"medium\")]\n\nfirstimg = read(imgnames[1])\nencoder = prepareencoder(firstimg, framerate=framerate, AVCodecContextProperties=props)\n\nio = Base.open(\"temp.stream\",\"w\")\np = Progress(length(imgstack), 1)\nindex = 1\nfor imgname in imgnames\n    global index\n    img = read(imgname)\n    appendencode!(encoder, io, img, index)\n    next!(p)\n    index += 1\nend\n\nfinishencode!(encoder, io)\nclose(io)\n\nmux(\"temp.stream\",filename,framerate) #Multiplexes the stream into a video container","category":"page"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"VideoIO.prepareencoder","category":"page"},{"location":"writing/#VideoIO.prepareencoder","page":"Writing Videos","title":"VideoIO.prepareencoder","text":"prepareencoder(firstimg;framerate=30,AVCodecContextProperties=[:privdata => (\"crf\"=>\"22\",\"preset\"=>\"medium\")],codecname::String=\"libx264\")\n\nPrepare encoder and return AV objects.\n\n\n\n\n\n","category":"function"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"VideoIO.appendencode!","category":"page"},{"location":"writing/#VideoIO.appendencode!","page":"Writing Videos","title":"VideoIO.appendencode!","text":"appendencode(encoder::VideoEncoder, io::IO, img, index::Integer)\n\nSend image object to ffmpeg encoder and encode\n\n\n\n\n\n","category":"function"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"VideoIO.finishencode!","category":"page"},{"location":"writing/#VideoIO.finishencode!","page":"Writing Videos","title":"VideoIO.finishencode!","text":"function finishencode(encoder::VideoEncoder, io::IO)\n\nEnd encoding by sending endencode package to ffmpeg, and close objects.\n\n\n\n\n\n","category":"function"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"VideoIO.mux","category":"page"},{"location":"writing/#VideoIO.mux","page":"Writing Videos","title":"VideoIO.mux","text":"mux(srcfilename,destfilename,framerate;silent=false)\n\nMultiplex stream object into video container.\n\n\n\n\n\n","category":"function"},{"location":"writing/#Supported-Colortypes-1","page":"Writing Videos","title":"Supported Colortypes","text":"","category":"section"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"Encoding of the following image element color types currently supported:","category":"page"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"UInt8\nGray{N0f8}\nRGB{N0f8}","category":"page"},{"location":"writing/#Encoder-settings-1","page":"Writing Videos","title":"Encoder settings","text":"","category":"section"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"The AVCodecContextProperties object allows control of the majority of settings required. Optional fields can be found here.","category":"page"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"A few helpful presets for h264:","category":"page"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"Goal AVCodecContextProperties value\nPerceptual compression, h264 default.<br>Best for most cases [:priv_data => (\"crf\"=>\"23\",\"preset\"=>\"medium\")\nLossless compression.<br>Fastest, largest file size [:priv_data => (\"crf\"=>\"0\",\"preset\"=>\"ultrafast\")]\nLossless compression.<br>Slowest, smallest file size [:priv_data => (\"crf\"=>\"0\",\"preset\"=>\"ultraslow\")]\nDirect control of bitrate and frequency of intra frames (every 10) [:bit_rate => 400000,:gop_size = 10,:max_b_frames=1]","category":"page"},{"location":"writing/#Lossless-encoding-1","page":"Writing Videos","title":"Lossless encoding","text":"","category":"section"},{"location":"writing/#Lossless-RGB-1","page":"Writing Videos","title":"Lossless RGB","text":"","category":"section"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"If lossless encoding of RGB{N0f8} is required, true lossless requires using codec_name = \"libx264rgb\", to avoid the lossy RGB->YUV420 conversion, and \"crf\" => \"0\".","category":"page"},{"location":"writing/#Lossless-Grayscale-1","page":"Writing Videos","title":"Lossless Grayscale","text":"","category":"section"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"If lossless encoding of Gray{N0f8} or UInt8 is required, \"crf\" => \"0\" should be set, as well as :color_range=>2 to ensure full 8-bit pixel color representation. i.e.  [:color_range=>2, :priv_data => (\"crf\"=>\"0\",\"preset\"=>\"medium\")]","category":"page"},{"location":"writing/#Encoding-Performance-1","page":"Writing Videos","title":"Encoding Performance","text":"","category":"section"},{"location":"writing/#","page":"Writing Videos","title":"Writing Videos","text":"See examples/lossless_video_encoding_testing.jl for testing of losslessness, speed, and compression as a function of h264 encoding preset, for 3 example videos.  ","category":"page"},{"location":"utilities/#Utilities-1","page":"Utilities","title":"Utilities","text":"","category":"section"},{"location":"utilities/#Test-Videos-1","page":"Utilities","title":"Test Videos","text":"","category":"section"},{"location":"utilities/#","page":"Utilities","title":"Utilities","text":"A small number of test videos are available through VideoIO.TestVideos. These are short videos in a variety of formats with non-restrictive (public domain or Creative Commons) licenses.","category":"page"},{"location":"utilities/#","page":"Utilities","title":"Utilities","text":"VideoIO.TestVideos.available","category":"page"},{"location":"utilities/#VideoIO.TestVideos.available","page":"Utilities","title":"VideoIO.TestVideos.available","text":"available()\n\nPrint a list of all available test videos.\n\n\n\n\n\n","category":"function"},{"location":"utilities/#","page":"Utilities","title":"Utilities","text":"VideoIO.testvideo","category":"page"},{"location":"utilities/#VideoIO.TestVideos.testvideo","page":"Utilities","title":"VideoIO.TestVideos.testvideo","text":"testvideo(name, ops...)\n\nReturns an AVInput object for the given video name. The video will be downloaded if it isn't available.\n\n\n\n\n\n","category":"function"},{"location":"utilities/#","page":"Utilities","title":"Utilities","text":"VideoIO.TestVideos.download_all","category":"page"},{"location":"utilities/#VideoIO.TestVideos.download_all","page":"Utilities","title":"VideoIO.TestVideos.download_all","text":"download_all()\n\nDownloads all test videos.\n\n\n\n\n\n","category":"function"},{"location":"utilities/#","page":"Utilities","title":"Utilities","text":"VideoIO.TestVideos.remove_all","category":"page"},{"location":"utilities/#VideoIO.TestVideos.remove_all","page":"Utilities","title":"VideoIO.TestVideos.remove_all","text":"remove_all()\n\nRemove all test videos.\n\n\n\n\n\n","category":"function"},{"location":"lowlevel/#Low-level-functionality-1","page":"Low Level Functionality","title":"Low level functionality","text":"","category":"section"},{"location":"lowlevel/#FFMPEG-log-level-1","page":"Low Level Functionality","title":"FFMPEG log level","text":"","category":"section"},{"location":"lowlevel/#","page":"Low Level Functionality","title":"Low Level Functionality","text":"FFMPEG's built-in logging and warning level can be read and set with","category":"page"},{"location":"lowlevel/#","page":"Low Level Functionality","title":"Low Level Functionality","text":"VideoIO.loglevel!","category":"page"},{"location":"lowlevel/#VideoIO.loglevel!","page":"Low Level Functionality","title":"VideoIO.loglevel!","text":"loglevel!(loglevel::Integer)\n\nSet FFMPEG log level. Options are:\n\nVideoIO.AVUtil.AV_LOG_QUIET\nVideoIO.AVUtil.AV_LOG_PANIC\nVideoIO.AVUtil.AV_LOG_FATAL\nVideoIO.AVUtil.AV_LOG_ERROR\nVideoIO.AVUtil.AV_LOG_WARNING\nVideoIO.AVUtil.AV_LOG_INFO\nVideoIO.AVUtil.AV_LOG_VERBOSE\nVideoIO.AVUtil.AV_LOG_DEBUG\nVideoIO.AVUtil.AV_LOG_TRACE\n\n\n\n\n\n","category":"function"},{"location":"lowlevel/#","page":"Low Level Functionality","title":"Low Level Functionality","text":"VideoIO.loglevel","category":"page"},{"location":"lowlevel/#VideoIO.loglevel","page":"Low Level Functionality","title":"VideoIO.loglevel","text":"loglevel() -> String\n\nGet FFMPEG log level as a variable name string.\n\n\n\n\n\n","category":"function"},{"location":"lowlevel/#FFMPEG-interface-1","page":"Low Level Functionality","title":"FFMPEG interface","text":"","category":"section"},{"location":"lowlevel/#","page":"Low Level Functionality","title":"Low Level Functionality","text":"Each ffmpeg library has its own VideoIO subpackage:","category":"page"},{"location":"lowlevel/#","page":"Low Level Functionality","title":"Low Level Functionality","text":"libavcodec    -> AVCodecs\nlibavdevice   -> AVDevice\nlibavfilter   -> AVFilters\nlibavformat   -> AVFormat\nlibavutil     -> AVUtil\nlibswscale    -> SWScale","category":"page"},{"location":"lowlevel/#","page":"Low Level Functionality","title":"Low Level Functionality","text":"The following three files are related to ffmpeg, but currently not exposed:","category":"page"},{"location":"lowlevel/#","page":"Low Level Functionality","title":"Low Level Functionality","text":"libswresample -> SWResample\nlibpostproc   -> PostProc   (not wrapped)","category":"page"},{"location":"lowlevel/#","page":"Low Level Functionality","title":"Low Level Functionality","text":"After importing VideoIO, you can import and use any of the subpackages directly","category":"page"},{"location":"lowlevel/#","page":"Low Level Functionality","title":"Low Level Functionality","text":"import VideoIO\nimport SWResample  # SWResample functions are now available","category":"page"},{"location":"lowlevel/#","page":"Low Level Functionality","title":"Low Level Functionality","text":"Note that much of the functionality of these subpackages is not enabled by default, to avoid long compilation times as they load.  To control what is loaded, each library version has a file which imports that's modules files.  For example, ffmpeg's libswscale-v2 files are loaded by VideoIO_PKG_DIR/src/ffmpeg/SWScale/v2/LIBSWSCALE.jl.","category":"page"},{"location":"lowlevel/#","page":"Low Level Functionality","title":"Low Level Functionality","text":"Check these files to enable any needed functionality that isn't already enabled. Note that you'll probably need to do this for each version of the package for ffmpeg, and that the interfaces do change some from version to version.","category":"page"},{"location":"lowlevel/#","page":"Low Level Functionality","title":"Low Level Functionality","text":"Note that, in general, the low-level functions are not very fun to use, so it is good to focus initially on enabling a nice, higher-level function for these interfaces.","category":"page"},{"location":"functionindex/#Index-1","page":"Index","title":"Index","text":"","category":"section"},{"location":"functionindex/#","page":"Index","title":"Index","text":"","category":"page"}]
}