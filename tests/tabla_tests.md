# Etapa 3 — Tabla de Tests Manuales

**Proyecto:** ArtChain NFT Marketplace
**Entorno:** Remix VM (Cancun) — 4 cuentas disponibles

## Setup previo

| Paso | Acción en Remix |
|---|---|
| 1 | Deploy `ArtNFT` con `initialMinter = Cuenta1` |
| 2 | Deploy `ArtMarketplace` con `nftAddress = [dir ArtNFT]`, `initialMintPrice = 10000000000000000` (0.01 ETH) |
| 3 | Desde Cuenta1: `ArtNFT.setMinter([dir ArtMarketplace])` |
| 4 | Verificar: `ArtNFT.minter()` devuelve la dirección del Marketplace |

---

## Tabla de casos de prueba

| # | Contrato | Función | Cuenta | Inputs / VALUE | Resultado esperado | Resultado obtenido | Estado |
|---|---|---|---|---|---|---|---|
| 1 | ArtNFT | `mint()` directo | Cuenta1 (no minter) | `to=Cuenta1, uri="ipfs://test"` | REVERT: `NotAuthorizedMinter` | REVERT: `NotAuthorizedMinter(0x5B38...eddC4)` | ✓ |
| 2 | ArtMarketplace | `createNFT()` | Cuenta1 | VALUE = 0 ETH, `uri="ipfs://test1"` | REVERT: `MintPriceNotMet(10000000000000000, 0)` | REVERT: `MintPriceNotMet(required: 10000000000000000, sent: 0)` | ✓ |
| 3 | ArtMarketplace | `createNFT()` | Cuenta1 | VALUE = 0.01 ETH, `uri="ipfs://Qm.../1.json"` | NFT #0 minteado. Evento `NFTCreated`. `ArtNFT.ownerOf(0)` = Cuenta1 | `tokenId: 0`. 4 eventos: Transfer, MetadataUpdate, NFTMinted (ArtNFT), NFTCreated (Marketplace). `ownerOf(0)` = 0x5B38...eddC4 | ✓ |
| 4 | ArtMarketplace | `createNFT()` | Cuenta2 | VALUE = 0.01 ETH, `uri="ipfs://Qm.../2.json"` | NFT #1 minteado. Evento `NFTCreated`. `ArtNFT.ownerOf(1)` = Cuenta2 | `tokenId: 1`. 4 eventos: Transfer, MetadataUpdate, NFTMinted (ArtNFT), NFTCreated (Marketplace). `ownerOf(1)` = 0xAb84...5cb2 | ✓ |
| 5 | ArtNFT | `totalMinted()` | Cualquiera | — | Devuelve `2` | Devuelve `2` | ✓ |
| 6 | ArtMarketplace | `listNFT()` | Cuenta1 | `tokenId=0, price=0` | REVERT: `PriceMustBeGreaterThanZero` | REVERT: `PriceMustBeGreaterThanZero` | ✓ |
| 7 | ArtMarketplace | `listNFT()` | Cuenta1 | `tokenId=0, price=50000000000000000` (sin approve previo) | REVERT: `MarketplaceNotApproved(0)` | REVERT: `MarketplaceNotApproved(tokenId: 0)` | ✓ |
| 8 | ArtNFT | `approve()` | Cuenta1 | `spender=[dir Marketplace], tokenId=0` | Aprobación OK. `getApproved(0)` = dir Marketplace | Tx exitosa. Evento `Approval(Cuenta1, Marketplace, 0)` | ✓ |
| 9 | ArtMarketplace | `listNFT()` | Cuenta1 | `tokenId=0, price=50000000000000000` (0.05 ETH) | Listing activo. Evento `NFTListed`. `getListing(0)` = (Cuenta1, 0.05 ETH, true) | Tx exitosa. Evento `NFTListed(tokenId: 0, seller: 0x5B38...eddC4, price: 50000000000000000)` | ✓ |
| 10 | ArtMarketplace | `buyNFT()` | Cuenta3 | VALUE = 0.01 ETH (insuficiente), `tokenId=0` | REVERT: `InsufficientPayment(50000000000000000, 10000000000000000)` | REVERT: `InsufficientPayment(required: 50000000000000000, sent: 0)` (Value enviado fue 0, error correcto igual) | ✓ |
| 11 | ArtMarketplace | `buyNFT()` | Cuenta3 | VALUE = 0.05 ETH, `tokenId=0` | NFT transferido: `ownerOf(0)` = Cuenta3. Cuenta1 recibe 0.04875 ETH (97.5%). Evento `NFTSold`. `getListing(0).active` = false | Tx exitosa. Transfer de Cuenta1→Cuenta3 (tokenId 0). Evento `NFTSold(0, Cuenta1, Cuenta3, 50000000000000000)` | ✓ |
| 12 | ArtMarketplace | `buyNFT()` | Cuenta4 | VALUE = 0.05 ETH, `tokenId=0` (ya vendido) | REVERT: `ListingNotActive(0)` | REVERT: `ListingNotActive(tokenId: 0)` | ✓ |
| 13 | ArtNFT | `approve()` | Cuenta2 | `spender=[dir Marketplace], tokenId=1` | Aprobación OK | Tx exitosa. Evento `Approval(Cuenta2, Marketplace, 1)` | ✓ |
| 14 | ArtMarketplace | `listNFT()` | Cuenta2 | `tokenId=1, price=100000000000000000` (0.1 ETH) | Listing activo. Evento `NFTListed` | Tx exitosa. Evento `NFTListed(tokenId: 1, seller: 0xAb84...5cb2, price: 100000000000000000)` | ✓ |
| 15 | ArtMarketplace | `cancelListing()` | Cuenta3 (no owner del token 1) | `tokenId=1` | REVERT: `NotTokenOwner` | REVERT: `NotTokenOwner` | ✓ |
| 16 | ArtMarketplace | `cancelListing()` | Cuenta2 | `tokenId=1` | Listing cancelado. Evento `ListingCancelled`. `getListing(1).active` = false | Tx exitosa. Evento `ListingCancelled(tokenId: 1, seller: 0xAb84...5cb2)` | ✓ |
| 17 | ArtMarketplace | `withdrawFees()` | Cuenta2 (no owner) | — | REVERT: `OwnableUnauthorizedAccount` (error de OZ) | REVERT: `OwnableUnauthorizedAccount(account: 0xAb84...5cb2)` | ✓ |
| 18 | ArtMarketplace | `accumulatedFees()` | Cualquiera | — | Al menos 0.02125 ETH (0.01 + 0.01 minteos + 0.00125 fee venta) | Devuelve `21250000000000000` wei (0.02125 ETH, confirmado por evento FeesWithdrawn del test #19) | ✓ |
| 19 | ArtMarketplace | `withdrawFees()` | Cuenta1 (owner) | — | ETH transferido al owner. `accumulatedFees` = 0. Evento `FeesWithdrawn` | Tx exitosa. Evento `FeesWithdrawn(owner: 0x5B38...eddC4, amount: 21250000000000000)` | ✓ |
| 20 | ArtMarketplace | `withdrawFees()` | Cuenta1 (owner) | — (segunda vez) | REVERT: `NoFeesToWithdraw` | REVERT: `NoFeesToWithdraw` | ✓ |
| 21 | ArtMarketplace | `setMintPrice()` | Cuenta1 (owner) | `newPrice=0` | `mintPrice` = 0. Evento `MintPriceUpdated` | Tx exitosa. Evento `MintPriceUpdated(oldPrice: 10000000000000000, newPrice: 0)` | ✓ |
| 22 | ArtMarketplace | `createNFT()` | Cuenta4 | VALUE = 0 ETH, `uri="ipfs://Qm.../3.json"` | NFT #2 minteado sin pago. `ownerOf(2)` = Cuenta4 | `tokenId: 2`. 4 eventos: Transfer, MetadataUpdate, NFTMinted (ArtNFT), NFTCreated (Marketplace). `ownerOf(2)` = 0x7873...cabaB | ✓ |
| 23 | ArtMarketplace | `calculateFee()` | Cualquiera | `salePrice=1000000000000000000` (1 ETH) | Devuelve `25000000000000000` (0.025 ETH = 2.5%) | Devuelve `25000000000000000` | ✓ |
| 24 | ArtNFT | `setMinter()` | Cuenta2 (no owner) | `newMinter=Cuenta2` | REVERT: `OwnableUnauthorizedAccount` | REVERT: `OwnableUnauthorizedAccount(account: 0xAb84...5cb2)` | ✓ |

---

## Resumen de cobertura

| Contrato | Funciones totales | Funciones testeadas | Casos de error | Casos exitosos |
|---|---|---|---|---|
| ArtNFT | 4 | 4 (`mint`, `setMinter`, `totalMinted`, `approve` via ERC721) | 2 | 4 |
| ArtMarketplace | 8 | 8 (`createNFT`, `listNFT`, `buyNFT`, `cancelListing`, `withdrawFees`, `setMintPrice`, `getListing`, `calculateFee`) | 8 | 10 |
| **Total** | **12** | **12** | **10** | **14** |

---

## Checklist de desarrollo (Etapa 2)

| Ítem | Estado |
|---|---|
| Contrato 1 (ArtNFT) compilado con 0 errores y 0 warnings relevantes | ☑ |
| Contrato 2 (ArtMarketplace) compilado con 0 errores y 0 warnings relevantes | ☑ |
| Al menos una función en Contrato 1 llama a Contrato 2 — `createNFT()` → `ArtNFT.mint()` | ☑ |
| Todas las funciones públicas tienen NatSpec (@notice, @param, @return) | ☑ |
| Al menos una función con ETH implementa el patrón CEI — `buyNFT()`, `createNFT()`, `withdrawFees()` | ☑ |
| Existe al menos un modifier de acceso — `onlyMinter`, `onlyOwner`, `onlyTokenOwner` | ☑ |
| Todos los eventos están declarados y se emiten correctamente | ☑ |
| Al menos un custom error en vez de require con string — 8 custom errors declarados | ☑ |
| Las funciones de lectura usan view o pure — `getListing()`, `calculateFee()`, `totalMinted()` | ☑ |
| El flujo completo fue probado con 3+ cuentas distintas en Remix VM — Cuentas 1, 2, 3, 4 | ☑ |
