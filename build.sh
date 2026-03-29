cd frontend && gleam run -m lustre/dev build
cd backend && gleam export erlang-shipment
mv backend/build/erlang-shipment .
