import gleam/bit_array
import gleam/bytes_builder
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/option.{None}
import gleam/otp/actor
import gleam/result
import grammy

pub type HelperError {
  Unparsable
}

pub fn main() {
  let assert Ok(_server) =
    grammy.new(init: fn() { #(Nil, None) }, handler: fn(msg, conn, state) {
      case msg {
        grammy.Packet(address, port, message) -> {
          io.println(
            grammy.ip_address_to_string(address)
            <> ":"
            <> int.to_string(port)
            <> " sent "
            <> bit_array.inspect(message),
          )

          let assert Ok(id) = bit_array.slice(message, 0, 2)
          let assert Ok(misc) = bit_array.slice(message, 2, 2)
          let assert Ok(qdcount) =
            slice_uint(from: message, index: 32, uint_size: 16)
          let assert Ok(queries) = bit_array.slice(message, 12, 6)

          io.debug(qdcount)
          io.debug(queries)

          let assert Ok(_nil) =
            grammy.send_to(
              conn,
              address,
              port,
              bytes_builder.from_bit_array(message),
            )
          actor.continue(state)
        }
        grammy.User(_user) -> {
          actor.continue(state)
        }
      }
    })
    |> grammy.port(4000)
    |> grammy.start

  process.sleep_forever()
}

fn slice_uint(
  from from: BitArray,
  index index: Int,
  uint_size uint_size: Int,
) -> Result(Int, HelperError) {
  case bit_array.slice(from, at: index / 8, take: uint_size / 8) {
    Ok(bits) -> {
      case bit_array_to_int(from: bits, uint_size: uint_size) {
        Ok(int) -> Ok(int)
        err -> err
      }
    }
    Error(Nil) -> Error(Unparsable)
  }
}

pub fn bit_array_to_int(
  from from: BitArray,
  uint_size uint_size: Int,
) -> Result(Int, HelperError) {
  case from {
    <<long:int-size(uint_size)>> -> Ok(long)
    _ -> Error(Unparsable)
  }
}
