#!/usr/bin/env python3
"""Attach C2PA provenance to a derived game sprite, with its generator source as the parent ingredient.

Our pixel-art pipeline (pixelize.py chroma key, downsample, quantize, re-encode) rebuilds each sprite from the
generator's raw JPEG. Re-encoding drops the generator's embedded C2PA manifest, so this step puts it back:
it writes a new manifest into the derived PNG/WebP that lists the original raw file (with its own
generator-signed manifest store) as the parent ingredient, and records what we did to it.

Signing uses a throwaway self-signed certificate created for each run. No private key is stored or committed.
The certificate is "untrusted" in validators, just like the generator's own ephemeral one. What matters here is
that the chain of provenance is kept.

Usage (needs `pip install c2pa-python cryptography`):
  python3 tools/art/c2pa_attach.py RAW.jpg DERIVED.png[/.webp] ["extra action note"]
"""
import datetime, json, mimetypes, os, sys, tempfile

import c2pa
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import NameOID, ExtendedKeyUsageOID

mimetypes.add_type('image/webp', '.webp')


def _ephemeral_signer():
    now = datetime.datetime.now(datetime.timezone.utc)
    ca_key = ec.generate_private_key(ec.SECP256R1())
    ca_name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Airron's Fall art pipeline (ephemeral CA)"),
                         x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Airron's Fall")])
    ca = (x509.CertificateBuilder().subject_name(ca_name).issuer_name(ca_name).public_key(ca_key.public_key())
          .serial_number(x509.random_serial_number()).not_valid_before(now - datetime.timedelta(minutes=5))
          .not_valid_after(now + datetime.timedelta(days=3650))
          .add_extension(x509.BasicConstraints(ca=True, path_length=None), critical=True)
          .add_extension(x509.KeyUsage(digital_signature=False, content_commitment=False, key_encipherment=False,
                                       data_encipherment=False, key_agreement=False, key_cert_sign=True, crl_sign=True,
                                       encipher_only=False, decipher_only=False), critical=True)
          .sign(ca_key, hashes.SHA256()))
    key = ec.generate_private_key(ec.SECP256R1())
    leaf = (x509.CertificateBuilder()
            .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Airron's Fall art pipeline"),
                                     x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Airron's Fall")]))
            .issuer_name(ca_name).public_key(key.public_key()).serial_number(x509.random_serial_number())
            .not_valid_before(now - datetime.timedelta(minutes=5)).not_valid_after(now + datetime.timedelta(days=3650))
            .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
            .add_extension(x509.KeyUsage(digital_signature=True, content_commitment=False, key_encipherment=False,
                                         data_encipherment=False, key_agreement=False, key_cert_sign=False, crl_sign=False,
                                         encipher_only=False, decipher_only=False), critical=True)
            .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.EMAIL_PROTECTION]), critical=False)
            .add_extension(x509.SubjectKeyIdentifier.from_public_key(key.public_key()), critical=False)
            .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(ca_key.public_key()), critical=False)
            .sign(ca_key, hashes.SHA256()))
    chain = leaf.public_bytes(serialization.Encoding.PEM) + ca.public_bytes(serialization.Encoding.PEM)
    pkey = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption())
    info = c2pa.C2paSignerInfo(alg=b"es256", sign_cert=chain, private_key=pkey, ta_url=None)
    return c2pa.Signer.from_info(info)


def attach(raw, derived, note=None):
    fmt = mimetypes.guess_type(derived)[0]
    actions = [
        {"action": "c2pa.opened", "parameters": {"ingredientIds": ["generator-source"]}},
        {"action": "c2pa.edited", "softwareAgent": {"name": "Airron's Fall pixelize.py"},
         "description": "Chroma key, despill, per-cell median downsample to a pixel grid, palette quantize, "
                        "outline, stray-pixel cleanup, nearest-neighbour upscale."},
    ]
    if note:
        actions.append({"action": "c2pa.edited", "softwareAgent": {"name": "Airron's Fall art scripts"}, "description": note})
    manifest = {
        "claim_generator_info": [{"name": "Airron's Fall art pipeline", "version": "1.0"}],
        "title": os.path.basename(derived),
        "format": fmt,
        "assertions": [
            {"label": "c2pa.actions.v2", "data": {"actions": actions}},
            {"label": "c2pa.creative_work", "data": {"author": [{"@type": "Organization", "name": "Airron's Fall"}],
                                                      "credit": "Created with Grok"}},
        ],
    }
    signer = _ephemeral_signer()
    # No thumbnails: keep the sprites small. The parent's own manifest store is still embedded in full.
    ctx = c2pa.Context.from_dict({"builder": {"thumbnail": {"enabled": False}}})
    with c2pa.Builder(json.dumps(manifest), ctx) as builder:
        with open(raw, 'rb') as f:
            builder.add_ingredient(json.dumps({"title": os.path.basename(raw), "relationship": "parentOf", "label": "generator-source"}), "image/jpeg", f)
        fd, tmp = tempfile.mkstemp(suffix=os.path.splitext(derived)[1]); os.close(fd)
        with open(derived, 'rb') as src, open(tmp, 'w+b') as dst:
            builder.sign(signer, fmt, src, dst)
    os.chmod(tmp, 0o644)
    os.replace(tmp, derived)


def verify(path):
    with c2pa.Reader(path) as r:
        j = json.loads(r.json())
    m = j['manifests'][j['active_manifest']]
    parents = [i for i in m.get('ingredients', []) if i.get('relationship') == 'parentOf']
    gen = None
    if parents and parents[0].get('active_manifest'):
        gen = j['manifests'][parents[0]['active_manifest']].get('claim_generator_info', [{}])[0].get('name')
    return j.get('validation_state'), len(parents), gen


if __name__ == '__main__':
    raw, derived = sys.argv[1], sys.argv[2]
    attach(raw, derived, sys.argv[3] if len(sys.argv) > 3 else None)
    print(derived, *verify(derived))
