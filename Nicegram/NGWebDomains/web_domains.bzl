# The single place the Nicegram web domain is written. Auxiliary entries are
# prefixed forms of the primary so the domain itself is never repeated; every
# domain in NICEGRAM_ALL_DOMAINS is claimed in the associated-domains entitlement.
NICEGRAM_PRIMARY_DOMAIN = "nicegram.me"
NICEGRAM_ALL_DOMAINS = [
    NICEGRAM_PRIMARY_DOMAIN,
    "www." + NICEGRAM_PRIMARY_DOMAIN,
]
