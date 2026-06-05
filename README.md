# ArtChain — NFT Marketplace on-chain

**ISI · UTN · 2026 · Tecnologías DLT · Trabajo Integrador**
**Dominio:** NFTs — Arte Digital
**Grupo:** Rojas, Marisol - Rumis, Lohana - Salvucci, Julián

---

## Etapa 1 — Diseño del sistema

| Campo | Tu respuesta |
|---|---|
| **Nombre del proyecto** | ArtChain — Marketplace de Arte Digital NFT |
| **Problema que resuelve** | Los artistas digitales no disponen de una plataforma on-chain transparente para acuñar y comercializar sus obras como NFTs sin depender de intermediarios centralizados. ArtChain permite que cualquier creador mintee un NFT pagando un precio mínimo, lo liste en el marketplace al precio que desee, y reciba el pago en ETH directamente al momento de la venta. El sistema cobra una comisión del 2.5% por transacción, gestionada de forma transparente y auditable en la blockchain. |
| **Contrato 1** | `ArtNFT.sol` — Token ERC-721. Guarda cada obra de arte digital como un token único con URI de metadata en IPFS. Solo el Marketplace puede mintear nuevos tokens (minter autorizado). |
| **Contrato 2** | `ArtMarketplace.sol` — Lógica del marketplace. Gestiona el minteo pagado, el listado de NFTs, la compra/venta con comisión del 2.5% y el retiro de fees por el owner. Llama a ArtNFT para crear tokens. |
| **Contrato 3 (opcional)** | No aplica — la arquitectura de 2 contratos cubre todos los requisitos. |
| **Interacción cross-contract principal** | `ArtMarketplace.createNFT(uri)` llama a `ArtNFT.mint(msg.sender, uri)`. El Marketplace es el único minter autorizado del contrato NFT. Verificable en Etherscan como internal transaction. |

---

## Diagrama de flujo

```
┌─────────────┐   createNFT(uri) + ETH   ┌──────────────────────┐
│  CREADOR    │ ─────────────────────────▶│                      │
└─────────────┘                           │   ArtMarketplace     │──── mint(creator, uri) ────▶┌──────────┐
                                          │                      │                              │  ArtNFT  │
┌─────────────┐   listNFT(id, price)      │  (cross-contract)    │◀─── tokenId ───────────────│          │
│  VENDEDOR   │ ─────────────────────────▶│                      │                              └──────────┘
└─────────────┘                           │                      │
                                          │                      │
┌─────────────┐   buyNFT(id) + ETH        │                      │   safeTransferFrom
│  COMPRADOR  │ ─────────────────────────▶│                      │──────────────────▶ NFT a comprador
└─────────────┘                           │                      │   ETH (97.5%)  ──▶ vendedor
                                          │                      │   ETH (2.5%)   ──▶ accumulatedFees
┌─────────────┐   withdrawFees()          │                      │
│   OWNER     │ ─────────────────────────▶│                      │──── ETH ──────────▶ owner
└─────────────┘                           └──────────────────────┘
```

---

## Arquitectura de contratos

### `ArtNFT.sol`
- Hereda: `ERC721URIStorage`, `Ownable`
- Variables: `minter` (address), `_nextTokenId` (uint256)
- Funciones: `mint()`, `setMinter()`, `totalMinted()`
- Eventos: `NFTMinted`, `MinterUpdated`
- Custom errors: `NotAuthorizedMinter`, `ZeroAddress`

### `ArtMarketplace.sol`
- Hereda: `Ownable`, `ReentrancyGuard`
- Referencia: `ArtNFT public immutable nftContract`
- Variables: `mintPrice`, `FEE_BASIS_POINTS = 250`, `accumulatedFees`, `mapping listings`
- Funciones: `createNFT()`, `listNFT()`, `buyNFT()`, `cancelListing()`, `withdrawFees()`, `setMintPrice()`, `getListing()`, `calculateFee()`
- Eventos: `NFTCreated`, `NFTListed`, `NFTSold`, `ListingCancelled`, `MintPriceUpdated`, `FeesWithdrawn`
- Custom errors: `PriceMustBeGreaterThanZero`, `MintPriceNotMet`, `InsufficientPayment`, `ListingNotActive`, `NotTokenOwner`, `MarketplaceNotApproved`, `NoFeesToWithdraw`, `TransferFailed`

---

## Decisiones de diseño clave

### 1. Separación de responsabilidades
`ArtNFT` solo gestiona tokens ERC-721. `ArtMarketplace` gestiona la lógica de negocio. Esta separación permite actualizar el marketplace en el futuro deployando uno nuevo y llamando `setMinter()` sin tocar los NFTs existentes.

### 2. Patrón CEI (Checks-Effects-Interactions)
Aplicado en `createNFT()`, `buyNFT()` y `withdrawFees()`. El estado se actualiza **siempre** antes de cualquier llamada externa o transferencia de ETH, eliminando el vector de reentrancy.

### 3. ReentrancyGuard como segunda capa
`nonReentrant` en todas las funciones `payable` como defensa en profundidad adicional al patrón CEI.

### 4. Pull Payment en fees
El owner retira fees activamente con `withdrawFees()` en lugar de recibir ETH automáticamente. Esto sigue el patrón Pull Payment y evita un vector de DoS si la dirección del owner fuera un contrato que rechaza ETH.

### 5. Aprobación previa para listings
El vendedor debe llamar `ArtNFT.approve(marketplace, tokenId)` antes de listar. Esto es el patrón estándar (similar a OpenSea) y evita que el marketplace tenga custodia de los NFTs.

---

## Secuencia de deploy (orden obligatorio)

```
1. Deployar ArtNFT con initialMinter = msg.sender (tu dirección)
   → Copiar dirección: 0x___________________

2. Deployar ArtMarketplace con:
   - nftAddress = dirección de ArtNFT
   - initialMintPrice = 10000000000000000  (0.01 ETH en wei)
   → Copiar dirección: 0x___________________

3. Llamar ArtNFT.setMinter(dirección_del_marketplace)
   → Ahora el Marketplace puede mintear NFTs

4. Verificar: ArtNFT.minter() debe devolver la dirección del Marketplace
```

---

## Etapa 4 — Tabla de evidencia del deploy en Sepolia

| Contrato | Dirección en Sepolia | URL Explorer | ¿Verificado? | Tx hash deploy |
|---|---|---|---|---|
| ArtNFT | `0x81879A236C1e757d3534F4Cb7cb3ec03F0028cF4` | [Etherscan](https://sepolia.etherscan.io/address/0x81879A236C1e757d3534F4Cb7cb3ec03F0028cF4) · [Blockscout](https://eth-sepolia.blockscout.com/address/0x81879A236C1e757d3534F4Cb7cb3ec03F0028cF4?tab=contract) | ✅ Sí (Sourcify + Blockscout) | `0x742e0bc8021ad81de1d78f92b2ab6336690563d051600f016a8e06baa062b2f6` |
| ArtMarketplace | `0x7C796167BF4b9D1ab223c76152FB7a0A7c7D61B3` | [Etherscan](https://sepolia.etherscan.io/address/0x7C796167BF4b9D1ab223c76152FB7a0A7c7D61B3) · [Blockscout](https://eth-sepolia.blockscout.com/address/0x7C796167BF4b9D1ab223c76152FB7a0A7c7D61B3?tab=contract) | ✅ Sí (Sourcify + Blockscout) | `0x1a4a605539aaea2449b45dcf842e5caf07ca2c8d67e59929d1dec85dc2789fb6` |
| setMinter (ArtNFT ← Marketplace) | — | [Etherscan](https://sepolia.etherscan.io/tx/0x037a598de23867ab19c7fbd9ff919538d7aa849c528150e24515b944ecff6bbb) | ✅ Confirmado: `ArtNFT.minter()` = `0x7C796167...` | `0x037a598de23867ab19c7fbd9ff919538d7aa849c528150e24515b944ecff6bbb` |
| Tx cross-contract (createNFT) | — | [Etherscan](https://sepolia.etherscan.io/tx/0x71be9126d3f73cd117a63630cf5563672deaf9b9d33eb72acd32e16d1f699899) · [Blockscout](https://eth-sepolia.blockscout.com/tx/0x71be9126d3f73cd117a63630cf5563672deaf9b9d33eb72acd32e16d1f699899) | ✅ | `0x71be9126d3f73cd117a63630cf5563672deaf9b9d33eb72acd32e16d1f699899` |
| Tx cross-contract (buyNFT) | — | [Etherscan](https://sepolia.etherscan.io/tx/0x8059d13a654e77bf1a64740baa4e3c25f412b439e43523895770ae644bd995bc) · [Blockscout](https://eth-sepolia.blockscout.com/tx/0x8059d13a654e77bf1a64740baa4e3c25f412b439e43523895770ae644bd995bc) | ✅ Transfer `0x2dac...` → `0x90A3...` (cuentas distintas) | `0x8059d13a654e77bf1a64740baa4e3c25f412b439e43523895770ae644bd995bc` |

---

## Recursos usados

| Recurso | URL |
|---|---|
| Solidity by Example | solidity-by-example.org |
| Remix IDE | remix.ethereum.org |
| OpenZeppelin Docs | docs.openzeppelin.com |
| OZ Wizard | wizard.openzeppelin.com |
| Sepolia Etherscan | sepolia.etherscan.io |
| Sepolia Faucet | sepoliafaucet.com |
| IPFS / Pinata | pinata.cloud |
