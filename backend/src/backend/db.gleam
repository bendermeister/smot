import backend/context
import backend/db_actor
import gleam/otp/actor
import middle/video

pub fn video_insert(ctx: context.Context, video: video.Video) {
  actor.call(ctx.db, 20_000, db_actor.VideoInsert(reply_to: _, video:))
}

pub fn video_fetch_all(ctx: context.Context) {
  actor.call(ctx.db, 20_000, db_actor.VideoFetchAll(reply_to: _))
}

pub fn video_fetch(ctx: context.Context, id: video.Id) {
  actor.call(ctx.db, 20_000, db_actor.VideoFetch(reply_to: _, id:))
}
