FROM erlang:28.3-alpine AS build
COPY --from=ghcr.io/gleam-lang/gleam:v1.15.1-erlang-alpine /bin/gleam /bin/gleam

RUN apk update
RUN apk upgrade
RUN apk add build-base
RUN apk add git

RUN git clone https://github.com/bendermeister/smot

RUN cd /smot/frontend && gleam run -m lustre/dev build
RUN cd /smot/backend && gleam export erlang-shipment

FROM erlang:28.3-alpine
RUN \
  addgroup --system webapp && \
  adduser --system webapp -g webapp
COPY --from=build /smot/backend/build/erlang-shipment /app
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
EXPOSE 8080
CMD ["run"]
