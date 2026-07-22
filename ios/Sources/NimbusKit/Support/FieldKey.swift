import Foundation

/// Canonical field keys used across protocol schemas, parsers and the tunnel
/// engine. Keys are plain strings so a new protocol module can introduce its own
/// keys without touching a central enum, but the well-known ones are gathered
/// here to avoid stringly-typed drift between a schema, its parser and the engine.
public enum FieldKey {
    // General
    public static let name = "name"
    public static let group = "group"

    // Endpoint
    public static let server = "server"
    public static let port = "port"
    public static let proto = "proto"          // openvpn udp/tcp
    public static let accept = "accept"         // stunnel local accept
    public static let endpoint = "endpoint"     // wireguard host:port

    // Credentials
    public static let uuid = "uuid"
    public static let username = "user"
    public static let password = "pw"
    public static let auth = "auth"             // hysteria2 shared secret
    public static let privateKey = "key"        // ssh private key
    public static let interfacePrivateKey = "privkey" // wireguard
    public static let peerPublicKey = "pubkey"  // wireguard
    public static let presharedKey = "psk"      // wireguard
    public static let realityPublicKey = "pbk"  // reality public key
    public static let cipher = "cipher"
    public static let alterID = "aid"           // vmess

    // TLS / security
    public static let security = "security"     // tls / reality / none
    public static let sni = "sni"
    public static let alpn = "alpn"
    public static let fingerprint = "fp"
    public static let shortID = "sid"           // reality short id
    public static let spiderX = "spx"           // reality spiderX
    public static let flow = "flow"             // xtls flow
    public static let allowInsecure = "insecure"
    public static let pinnedSHA256 = "pin"
    public static let caCertificate = "ca"
    public static let tlsAuthKey = "tlsauth"
    public static let verifyChain = "verify"

    // Transport
    public static let network = "net"           // tcp / ws / grpc / xhttp / h2 / kcp
    public static let path = "path"
    public static let hostHeader = "host"
    public static let serviceName = "serviceName"
    public static let webSocketHost = "wsHost"

    // WireGuard
    public static let address = "address"
    public static let dns = "dns"
    public static let mtu = "mtu"
    public static let allowedIPs = "allowed"
    public static let keepAlive = "keepalive"

    // Hysteria2 / TUIC
    public static let up = "up"
    public static let down = "down"
    public static let obfs = "obfs"
    public static let obfsPassword = "obfspw"
    public static let congestionControl = "cc"
    public static let udpRelayMode = "udp"
    public static let zeroRTT = "zerortt"

    // Shadowsocks plugin
    public static let plugin = "plugin"
    public static let pluginOptions = "popts"
    public static let udpOverTCP = "uot"

    // Multiplex / sniffing
    public static let multiplex = "mux"
    public static let sniffing = "sniff"

    // SSH payload mode
    public static let tunnelMode = "mode"       // Direct / SSL/TLS / WebSocket / HTTP
    public static let httpPayload = "payload"

    // Misc
    public static let compression = "comp"
    public static let compressionLZO = "compress"
    public static let timeout = "timeout"
}
