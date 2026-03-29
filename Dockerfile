FROM erlang:28.3-alpine AS build
COPY --from=ghcr.io/gleam-lang/gleam:v1.15.1-erlang-alpine /bin/gleam /bin/gleam
RUN mkdir /build
RUN apk update
RUN apk upgrade
RUN apk add build-base

COPY . /build
RUN cd /build/frontend && gleam clean
RUN cd /build/backend && gleam clean

RUN cd /build/frontend && gleam run -m lustre/dev build
RUN cd /build/backend && gleam export erlang-shipment

FROM erlang:28.3-alpine
RUN \
  addgroup --system webapp && \
  adduser --system webapp -g webapp
COPY --from=build /build/backend/build/erlang-shipment /app
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
EXPOSE 8080
CMD ["run"]
