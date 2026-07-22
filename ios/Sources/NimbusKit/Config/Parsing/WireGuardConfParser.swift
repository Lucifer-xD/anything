import Foundation

/// Parses a WireGuard `.conf` (the `[Interface]` / `[Peer]` INI format) into a
/// ``TunnelConfiguration``. This is the canonical WireGuard import path since
/// WireGuard has no share-link URI.
public enum WireGuardConfParser {
    public static func parse(_ text: String, name suggestedName: String? = nil) throws -> TunnelConfiguration {
        var section = ""
        var iface: [String: String] = [:]
        var peer: [String: String] = [:]
        var commentName: String?

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("#") {
                // Support a leading "# Name = X" hint.
                let body = line.dropFirst().trimmingCharacters(in: .whitespaces)
                if body.lowercased().hasPrefix("name"), let eq = body.firstIndex(of: "=") {
                    commentName = body[body.index(after: eq)...].trimmingCharacters(in: .whitespaces)
                }
                continue
            }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                section = line.dropFirst().dropLast().lowercased()
                continue
            }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if section == "interface" { iface[key] = value }
            else if section == "peer" { peer[key] = value }
        }

        guard let privateKey = iface["privatekey"], !privateKey.isEmpty else {
            throw NimbusError.parseFailure(scheme: "wireguard", reason: "missing [Interface] PrivateKey")
        }
        guard let publicKey = peer["publickey"], !publicKey.isEmpty else {
            throw NimbusError.parseFailure(scheme: "wireguard", reason: "missing [Peer] PublicKey")
        }
        guard let endpoint = peer["endpoint"], !endpoint.isEmpty else {
            throw NimbusError.parseFailure(scheme: "wireguard", reason: "missing [Peer] Endpoint")
        }

        var fields = ConfigFields()
        fields.set(FieldKey.name, commentName ?? suggestedName ?? Endpoint(endpoint)?.host ?? "WireGuard")
        fields.set(FieldKey.interfacePrivateKey, privateKey)
        fields.setIfPresent(FieldKey.address, iface["address"])
        fields.setIfPresent(FieldKey.dns, iface["dns"])
        if let mtu = iface["mtu"], let value = Int(mtu) { fields.set(FieldKey.mtu, value) }
        fields.set(FieldKey.peerPublicKey, publicKey)
        fields.setIfPresent(FieldKey.presharedKey, peer["presharedkey"])
        fields.set(FieldKey.endpoint, endpoint)
        fields.set(FieldKey.allowedIPs, peer["allowedips"] ?? "0.0.0.0/0, ::/0")
        if let keepalive = peer["persistentkeepalive"], let value = Int(keepalive) {
            fields.set(FieldKey.keepAlive, value)
        }
        // Mirror host/port so universal accessors work.
        if let ep = Endpoint(endpoint) {
            fields.set(FieldKey.server, ep.host)
            fields.set(FieldKey.port, ep.port)
        }

        return TunnelConfiguration(kind: .wireguard, fields: fields, metadata: ConfigMetadata(source: .file))
    }

    /// Heuristic: does this text look like a WireGuard conf?
    public static func matches(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("[interface]") && lower.contains("privatekey")
    }
}
