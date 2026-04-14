import crypto from "node:crypto"
import process from "node:process"
import mqtt from "mqtt"

const [, , endpoint, thingName, payloadJson] = process.argv
const token = process.env.SNOO_ID_TOKEN

if (!endpoint || !token || !thingName || !payloadJson) {
  console.error("usage: SNOO_ID_TOKEN=... node script/snoo_mqtt_command.mjs <endpoint> <thingName> <payloadJson>")
  process.exit(1)
}

let payload

try {
  payload = JSON.parse(payloadJson)
} catch (error) {
  console.error(`invalid payload json: ${error.message}`)
  process.exit(1)
}

const client = mqtt.connect(`wss://${endpoint}/mqtt`, {
  protocol: "wss",
  protocolId: "MQIsdp",
  protocolVersion: 3,
  clientId: `snoo_rb_${crypto.randomBytes(6).toString("hex")}`,
  username: "?SDK=iOS&Version=2.40.1",
  clean: true,
  connectTimeout: 10_000,
  reconnectPeriod: 0,
  keepalive: 30,
  wsOptions: {
    headers: {
      token
    }
  }
})

const timeout = setTimeout(() => {
  console.error("mqtt publish timed out")
  client.end(true)
  process.exit(1)
}, 15_000)

client.on("connect", () => {
  client.publish(`${thingName}/state_machine/control`, JSON.stringify(payload), {}, (error) => {
    if (error) {
      clearTimeout(timeout)
      console.error(`mqtt publish failed: ${error.message}`)
      client.end(true)
      process.exit(1)
      return
    }

    clearTimeout(timeout)
    process.stdout.write(JSON.stringify({ ok: true }))
    client.end(false, () => process.exit(0))
  })
})

client.on("error", (error) => {
  clearTimeout(timeout)
  console.error(`mqtt connection failed: ${error.message}`)
  client.end(true)
  process.exit(1)
})
