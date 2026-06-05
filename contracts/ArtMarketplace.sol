// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ArtNFT.sol";

/**
 * @title ArtMarketplace
 * @author ArtChain Team — ISI UTN 2026
 * @notice Marketplace para mintear y comerciar ArtChain NFTs.
 *         Permite a los creadores acuñar NFTs pagando una tarifa de minteo,
 *         listarlos a la venta y que los compradores los adquieran con ETH.
 *         El marketplace retiene un 2.5% de cada venta como comisión.
 * @dev Llama a ArtNFT.mint() (cross-contract). Patrón CEI y ReentrancyGuard
 *      en todas las funciones que manejan ETH para prevenir reentrancy.
 */
contract ArtMarketplace is Ownable, ReentrancyGuard {

    // ── Custom errors ─────────────────────────────────────────────────────────

    /// @notice El precio de listado debe ser mayor a cero.
    error PriceMustBeGreaterThanZero();

    /// @notice El ETH enviado no alcanza el mintPrice requerido.
    error MintPriceNotMet(uint256 required, uint256 sent);

    /// @notice El ETH enviado no alcanza el precio del listing.
    error InsufficientPayment(uint256 required, uint256 sent);

    /// @notice El tokenId no tiene un listing activo en este momento.
    error ListingNotActive(uint256 tokenId);

    /// @notice El caller no es el dueño del token.
    error NotTokenOwner();

    /// @notice El marketplace no tiene aprobación para transferir el token.
    error MarketplaceNotApproved(uint256 tokenId);

    /// @notice No hay fees acumuladas disponibles para retirar.
    error NoFeesToWithdraw();

    /// @notice La transferencia de ETH falló.
    error TransferFailed();

    // ── Types ─────────────────────────────────────────────────────────────────

    /**
     * @notice Datos de un listing activo.
     * @param seller Dirección del vendedor.
     * @param price Precio de venta en wei.
     * @param active Si el listing está activo y disponible para comprar.
     */
    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    // ── State variables ───────────────────────────────────────────────────────

    /// @notice Referencia inmutable al contrato ArtNFT asociado.
    ArtNFT public immutable nftContract;

    /// @notice Precio en wei requerido para mintear un nuevo NFT.
    uint256 public mintPrice;

    /// @notice Fee del marketplace en basis points (250 = 2.5%).
    uint256 public constant FEE_BASIS_POINTS = 250;

    /// @notice ETH acumulado por fees del marketplace, retirable por el owner.
    uint256 public accumulatedFees;

    /// @notice Mapeo de tokenId a los datos de su listing.
    mapping(uint256 => Listing) public listings;

    // ── Events ────────────────────────────────────────────────────────────────

    /// @notice Emitido cuando se mintea un nuevo NFT a través del marketplace.
    event NFTCreated(address indexed creator, uint256 indexed tokenId, string uri);

    /// @notice Emitido cuando un NFT es puesto a la venta.
    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);

    /// @notice Emitido cuando se concreta la compra de un NFT.
    event NFTSold(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 price
    );

    /// @notice Emitido cuando se cancela un listing activo.
    event ListingCancelled(uint256 indexed tokenId, address indexed seller);

    /// @notice Emitido cuando el owner actualiza el precio de minteo.
    event MintPriceUpdated(uint256 oldPrice, uint256 newPrice);

    /// @notice Emitido cuando el owner retira las fees acumuladas.
    event FeesWithdrawn(address indexed owner, uint256 amount);

    // ── Modifiers ─────────────────────────────────────────────────────────────

    /// @dev Verifica que msg.sender sea el dueño del token indicado.
    modifier onlyTokenOwner(uint256 tokenId) {
        if (nftContract.ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        _;
    }

    // ── Constructor ───────────────────────────────────────────────────────────

    /**
     * @notice Deploya el marketplace y lo conecta al contrato ArtNFT.
     * @dev Luego del deploy, llamar a ArtNFT.setMinter(address(this)) para autorizar
     *      este contrato a mintear NFTs.
     * @param nftAddress Dirección del contrato ArtNFT previamente deployado.
     * @param initialMintPrice Precio en wei para mintear un nuevo NFT (0 = gratis).
     */
    constructor(address nftAddress, uint256 initialMintPrice) Ownable(msg.sender) {
        nftContract = ArtNFT(nftAddress);
        mintPrice = initialMintPrice;
    }

    // ── External functions ────────────────────────────────────────────────────

    /**
     * @notice Crea y mintea un nuevo NFT pagando el mintPrice.
     * @dev INTERACCIÓN CROSS-CONTRACT: llama a ArtNFT.mint(). Patrón CEI:
     *      1. CHECK: msg.value >= mintPrice
     *      2. EFFECT: acumular fee
     *      3. INTERACTION: llamar a ArtNFT.mint()
     * @param uri URI de metadata IPFS del nuevo NFT (formato: ipfs://CID/metadata.json).
     * @return tokenId El ID del token recién minteado.
     */
    function createNFT(string calldata uri)
        external
        payable
        nonReentrant
        returns (uint256 tokenId)
    {
        // CHECK
        if (msg.value < mintPrice) revert MintPriceNotMet(mintPrice, msg.value);

        // EFFECT
        accumulatedFees += msg.value;

        // INTERACTION — cross-contract call a ArtNFT
        tokenId = nftContract.mint(msg.sender, uri);

        emit NFTCreated(msg.sender, tokenId, uri);
    }

    /**
     * @notice Pone un NFT propio a la venta al precio indicado.
     * @dev El caller debe llamar a ArtNFT.approve(marketplace, tokenId) primero.
     * @param tokenId ID del NFT a listar.
     * @param price Precio de venta en wei. Debe ser mayor a cero.
     */
    function listNFT(uint256 tokenId, uint256 price)
        external
        onlyTokenOwner(tokenId)
    {
        if (price == 0) revert PriceMustBeGreaterThanZero();
        if (
            nftContract.getApproved(tokenId) != address(this) &&
            !nftContract.isApprovedForAll(msg.sender, address(this))
        ) revert MarketplaceNotApproved(tokenId);

        listings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            active: true
        });

        emit NFTListed(tokenId, msg.sender, price);
    }

    /**
     * @notice Compra un NFT listado. El comprador envía al menos el precio del listing.
     * @dev Patrón CEI:
     *      1. CHECKS: listing activo, pago suficiente
     *      2. EFFECTS: desactivar listing, calcular y acumular fee
     *      3. INTERACTIONS: transferir NFT, pagar al vendedor, devolver excedente
     *      El 2.5% de comisión queda retenido en el contrato para el owner.
     * @param tokenId ID del NFT a comprar.
     */
    function buyNFT(uint256 tokenId) external payable nonReentrant {
        Listing memory listing = listings[tokenId];

        // CHECKS
        if (!listing.active) revert ListingNotActive(tokenId);
        if (msg.value < listing.price)
            revert InsufficientPayment(listing.price, msg.value);

        // EFFECTS
        listings[tokenId].active = false;
        uint256 fee = (listing.price * FEE_BASIS_POINTS) / 10_000;
        uint256 sellerProceeds = listing.price - fee;
        accumulatedFees += fee;

        // INTERACTIONS
        nftContract.safeTransferFrom(listing.seller, msg.sender, tokenId);

        (bool ok, ) = listing.seller.call{value: sellerProceeds}("");
        if (!ok) revert TransferFailed();

        uint256 excess = msg.value - listing.price;
        if (excess > 0) {
            (bool refundOk, ) = msg.sender.call{value: excess}("");
            if (!refundOk) revert TransferFailed();
        }

        emit NFTSold(tokenId, listing.seller, msg.sender, listing.price);
    }

    /**
     * @notice Cancela el listing activo de un NFT propio.
     * @param tokenId ID del NFT a deslistar.
     */
    function cancelListing(uint256 tokenId) external onlyTokenOwner(tokenId) {
        if (!listings[tokenId].active) revert ListingNotActive(tokenId);

        listings[tokenId].active = false;

        emit ListingCancelled(tokenId, msg.sender);
    }

    /**
     * @notice Retira todas las fees acumuladas del marketplace al owner.
     * @dev Patrón CEI: saldo puesto a cero ANTES de transferir ETH.
     */
    function withdrawFees() external onlyOwner nonReentrant {
        // CHECK
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NoFeesToWithdraw();

        // EFFECT
        accumulatedFees = 0;

        // INTERACTION
        (bool ok, ) = owner().call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit FeesWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Actualiza el precio de minteo para nuevos NFTs.
     * @dev Solo el owner puede llamarlo.
     * @param newPrice Nuevo precio en wei (0 para minteo gratuito).
     */
    function setMintPrice(uint256 newPrice) external onlyOwner {
        emit MintPriceUpdated(mintPrice, newPrice);
        mintPrice = newPrice;
    }

    // ── View / Pure functions ─────────────────────────────────────────────────

    /**
     * @notice Devuelve los detalles del listing de un token.
     * @param tokenId ID del token a consultar.
     * @return seller Dirección del vendedor.
     * @return price Precio de venta en wei.
     * @return active Si el listing está activo.
     */
    function getListing(uint256 tokenId)
        external
        view
        returns (address seller, uint256 price, bool active)
    {
        Listing memory l = listings[tokenId];
        return (l.seller, l.price, l.active);
    }

    /**
     * @notice Calcula el fee del marketplace para un precio de venta dado.
     * @param salePrice Precio de venta en wei.
     * @return El monto del fee (2.5% del precio).
     */
    function calculateFee(uint256 salePrice) external pure returns (uint256) {
        return (salePrice * FEE_BASIS_POINTS) / 10_000;
    }
}
