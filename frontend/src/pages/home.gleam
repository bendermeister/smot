import api
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/pair
import gleam/result
import gleam/set
import gleam/string
import gleam/uri
import icon
import layout/base.{layout}
import lustre/attribute.{class, href, placeholder, src, value}
import lustre/effect
import lustre/element/html.{a, button, div, img, input, label, text, textarea}
import lustre/event.{on_click, on_input}
import middle/author
import middle/id.{type Id}
import middle/timestamp
import middle/video.{type Video, Video}

pub type EditState {
  EditState(video: Video, tags: String)
}

pub type Model {
  Model(videos: List(Video), query: String, edit: Option(EditState))
}

pub type Msg {
  ClientGotVideos(videos: List(Video))
  ClientGotError(error: String)
  ClientGotVideo(video: Video)
  UserInputQuery(query: String)
  UserClickedAdd
  UserClickedEditVideo(video: Video)
  UserClosedEditVideo
  UserUpdatedVideoTitle(title: String)
  UserUpdatedVideoAuthor(name: String)
  UserUpdatedVideoTags(tags: String)
  UserDeletedVideo(id: Id(Video))
  UserSavedVideo
  NoOp
}

fn video_query(videos: List(Video), query: String) {
  let #(tags, query) =
    query
    |> string.replace(",", " ")
    |> string.replace(".", " ")
    |> string.replace(";", " ")
    |> string.replace("\t", " ")
    |> string.replace("\n", " ")
    |> string.lowercase()
    |> string.split(" ")
    |> list.partition(fn(part) {
      case part {
        "#" <> _ -> True
        _ -> False
      }
    })
  let tags = set.from_list(tags)

  videos
  |> list.map(fn(video) {
    let tag_count =
      video.tags
      |> set.from_list()
      |> set.intersection(tags)
      |> set.size()

    let author_count =
      query
      |> list.count(fn(query) {
        video.author.name
        |> string.lowercase()
        |> string.contains(query)
      })

    let title_count =
      query
      |> list.count(fn(query) {
        video.title
        |> string.lowercase()
        |> string.contains(query)
      })

    #(tag_count, author_count, title_count, video)
  })
  |> list.sort(fn(a, b) {
    int.compare(a.0, b.0)
    |> order.break_tie(int.compare(a.1, b.1))
    |> order.break_tie(int.compare(a.2, b.2))
    |> order.break_tie(timestamp.compare(a.3.timestamp, b.3.timestamp))
    |> order.negate()
  })
  |> list.map(fn(x) { x.3 })
}

pub fn init() {
  let fetch_video = api.video_fetch_all(ClientGotVideos, ClientGotError)

  #(Model(edit: None, videos: [], query: ""), fetch_video)
}

pub fn update(model: Model, msg: Msg) {
  case msg {
    ClientGotVideos(videos:) ->
      videos
      |> list.append(model.videos)
      |> list.unique
      |> list.sort(fn(a, b) {
        timestamp.compare(a.timestamp, b.timestamp)
        |> order.negate
      })
      |> fn(videos) { Model(..model, videos:) }
      |> pair.new(effect.none())

    ClientGotError(error:) -> {
      io.println_error(error)

      #(model, effect.none())
    }

    UserInputQuery(query:) -> {
      let videos = video_query(model.videos, query)
      #(Model(..model, videos:, query:), effect.none())
    }

    UserClickedAdd ->
      model.query
      |> uri.parse()
      |> result.try(video.id_from_uri)
      |> result.map(api.video_fetch(_, ClientGotVideo, ClientGotError))
      |> result.unwrap(
        effect.from(fn(dispatch) {
          dispatch(ClientGotError("this is not a valid youtube uri"))
        }),
      )
      |> pair.new(model, _)

    ClientGotVideo(video:) -> {
      let effect = api.video_insert(video, fn(_) { NoOp }, ClientGotError)
      let videos =
        [video, ..model.videos]
        |> list.unique()

      #(Model(..model, videos:, query: ""), effect)
      |> echo
    }

    NoOp -> #(model, effect.none())

    UserClickedEditVideo(video:) -> {
      let tags =
        video.tags
        |> string.join("\n")

      let edit =
        EditState(video:, tags:)
        |> Some

      #(Model(..model, edit:), effect.none())
    }

    UserClosedEditVideo -> #(Model(..model, edit: None), effect.none())

    UserUpdatedVideoTitle(title:) ->
      case model.edit {
        Some(EditState(video:, ..) as state) ->
          Video(..video, title:)
          |> fn(video) { EditState(..state, video:) }
          |> Some
          |> fn(edit) { Model(..model, edit:) }
          |> pair.new(effect.none())
        None -> #(model, effect.none())
      }

    UserUpdatedVideoAuthor(name:) ->
      case model.edit {
        Some(EditState(video:, ..) as state) ->
          Video(..video, author: author.Author(..video.author, name:))
          |> fn(video) { EditState(..state, video:) }
          |> Some
          |> fn(edit) { Model(..model, edit:) }
          |> pair.new(effect.none())
        None -> #(model, effect.none())
      }

    UserUpdatedVideoTags(tags:) ->
      case model.edit {
        Some(state) ->
          EditState(..state, tags:)
          |> Some
          |> fn(edit) { Model(..model, edit:) }
          |> pair.new(effect.none())
        None -> #(model, effect.none())
      }

    UserSavedVideo ->
      case model.edit {
        Some(EditState(video:, tags:)) -> {
          let tags =
            tags
            |> string.split(" ")
            |> list.map(string.replace(_, ",", ""))
            |> list.flat_map(string.split(_, "\t"))
            |> list.flat_map(string.split(_, "\n"))

          let video = Video(..video, tags:)

          // TODO: actually save this to server

          let effect = api.video_update(video, fn(_) { NoOp }, ClientGotError)

          let tags = tags |> string.join("\n")

          let edit =
            EditState(video:, tags:)
            |> Some

          #(Model(..model, edit:), effect)
        }
        None -> #(model, effect.none())
      }

    UserDeletedVideo(id:) -> {
      let effect = api.video_delete(id, fn(_) { NoOp }, ClientGotError)
      let videos =
        model.videos
        |> list.filter(fn(video) { video.id != id })

      #(Model(..model, videos:, edit: None), effect)
    }
  }
}

fn view_video(video: Video) {
  let url =
    video.id
    |> video.id_to_uri
    |> uri.to_string

  div(
    [
      class("w-[384px] h-fit"),
      class("flex flex-col gap-2"),
      class("transition-all hover:transform-[scale(0.975)]"),
    ],
    [
      a([href(url)], [
        img([
          class("w-[384px] h-[216px] object-cover"),
          src(video.thumbnail),
        ]),
      ]),
      div([class("flex flex-row justify-between")], [
        div([class("w-[360px] flex flex-col")], [
          div([class("line-clamp-1 text-ellipsis")], [text(video.title)]),
          div([class("line-clamp-1 text-ellipsis text-xs text-gray-500")], [
            text(video.author.name),
          ]),
        ]),
        div(
          [
            on_click(UserClickedEditVideo(video)),
            class("hover:cursor-pointer"),
            class("w-[24px]"),
          ],
          [icon.vertical_ellipsis()],
        ),
      ]),
    ],
  )
}

fn view_controls(query: String) {
  div(
    [
      class("w-full h-[2.5rem] flex flex-row gap-2"),
    ],
    [
      input([
        class("outline-none p-2 flex-grow border"),
        placeholder("search..."),
        on_input(UserInputQuery),
        value(query),
      ]),
      button(
        [
          on_click(UserClickedAdd),
          class("hover:cursor-pointer px-[2.5rem] py-2 border"),
        ],
        [
          text("add"),
        ],
      ),
    ],
  )
}

fn view_video_grid(videos: List(Video)) {
  let videos =
    videos
    |> list.map(view_video)

  div(
    [
      class("grid-cols-[repeat(auto-fit,384px)] grid gap-2 "),
      class("justify-center items-start"),
      class("flex-grow overflow-y-scroll no-scrollbar"),
    ],
    videos,
  )
}

pub fn view_edit(state: EditState) {
  let fieldset = fn(title, content, update) {
    div([class("flex flex-col gap-0")], [
      label([class("text-gray-500 text-sm")], [text(title)]),
      textarea([on_input(update), class("p-2 border outline-none")], content),
    ])
  }

  div(
    [
      class("w-fit h-full overflow-y-scroll p-2 border"),
      class("h-full flex flex-col gap-2 no-scrollbar"),
    ],
    [
      div([class("w-[384px] h-[216px]")], [
        img([
          class("w-full h-full object-cover"),
          src(state.video.thumbnail),
        ]),
      ]),

      fieldset("title", state.video.title, UserUpdatedVideoTitle),
      fieldset("author", state.video.author.name, UserUpdatedVideoAuthor),
      fieldset("tags", state.tags, UserUpdatedVideoTags),

      div([class("flex-grow")], []),
      div([class("w-full flex flex-row justify-between items-center")], [
        button(
          [
            on_click(UserClosedEditVideo),
            class("hover:cursor-pointer w-24 border p-2"),
          ],
          [text("close")],
        ),

        div([class("flex flex-row justify-end items-center gap-2")], [
          button(
            [
              on_click(UserDeletedVideo(state.video.id)),
              class("hover:cursor-pointer w-24 border p-2"),
            ],
            [
              text("delete"),
            ],
          ),
          button(
            [
              on_click(UserSavedVideo),
              class("hover:cursor-pointer w-24 border p-2"),
            ],
            [text("save")],
          ),
        ]),
      ]),
    ],
  )
}

pub fn view(model: Model) {
  case model.edit {
    Some(video) ->
      div([class("w-full h-full flex flex-row gap-2")], [
        div([class("h-full sm:flex flex-col gap-2 flex-grow hidden")], [
          view_controls(model.query),
          view_video_grid(model.videos),
        ]),
        view_edit(video),
      ])
    None ->
      div([class("w-full h-full flex flex-col gap-2")], [
        view_controls(model.query),
        view_video_grid(model.videos),
      ])
  }
  |> layout()
}
