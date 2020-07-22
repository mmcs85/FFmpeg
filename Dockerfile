FROM trzeci/emscripten:1.39.10-upstream

RUN apt-get update && apt-get install -y nano git python build-essential automake libtool pkg-config yasm && apt-get clean \
    && cd / && git clone https://github.com/mmcs85/FFmpeg.git /src
