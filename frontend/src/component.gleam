import component/video
import middle/video.{type Video} as _

pub fn register() {
  let assert Ok(_) = video.register()
}

pub fn video(attributes) {
  video.element(attributes)
}

pub fn video_data(video: Video) {
  video.property(video)
}
