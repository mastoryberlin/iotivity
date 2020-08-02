# iotivity

A work-in-progress solution to enable Internet of Things (IoT)
prototyping using [IoTivity](https://iotivity.org/getting-started).
IoTivity is the reference implementation of the [OCF](https://openconnectivity.org/developer/)
standard for IoT device interoperability.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     iotivity:
       github: mastoryberlin/iotivity
   ```

2. Run `shards install`

## Usage

```crystal
require "iotivity"

class MyClientApp
  include IoTivity::Client
  property server_endpoints : OC::Endpoint* = Pointer(OC::Endpoint).null

end

app = MyClientApp.new
app.run_client storage_dir: "./creds"
```

TODO: Write usage instructions here

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/mastoryberlin/iotivity/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Mastory](https://github.com/mastoryberlin) - creator and maintainer
