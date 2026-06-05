// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ArtNFT
 * @author ArtChain Team — ISI UTN 2026
 * @notice Token ERC-721 que representa obras de arte digital. Solo el minter autorizado
 *         (el Marketplace) puede crear nuevos tokens.
 * @dev Extiende ERC721URIStorage para almacenar una URI de metadata IPFS por token.
 */
contract ArtNFT is ERC721URIStorage, Ownable {

    // ── Custom errors ─────────────────────────────────────────────────────────

    /// @notice El caller no es la dirección autorizada como minter.
    error NotAuthorizedMinter(address caller);

    /// @notice Se intentó asignar la dirección cero.
    error ZeroAddress();

    // ── State variables ───────────────────────────────────────────────────────

    /// @notice Dirección autorizada a crear nuevos tokens (el contrato ArtMarketplace).
    address public minter;

    /// @dev Contador interno del próximo tokenId a emitir.
    uint256 private _nextTokenId;

    // ── Events ────────────────────────────────────────────────────────────────

    /// @notice Emitido cada vez que se crea un nuevo NFT.
    event NFTMinted(address indexed to, uint256 indexed tokenId, string tokenURI);

    /// @notice Emitido cuando el owner actualiza la dirección del minter.
    event MinterUpdated(address indexed oldMinter, address indexed newMinter);

    // ── Modifiers ─────────────────────────────────────────────────────────────

    /// @dev Restringe el acceso exclusivamente al minter autorizado.
    modifier onlyMinter() {
        if (msg.sender != minter) revert NotAuthorizedMinter(msg.sender);
        _;
    }

    // ── Constructor ───────────────────────────────────────────────────────────

    /**
     * @notice Deploya el contrato ArtNFT.
     * @dev El minter inicial puede ser msg.sender; luego se actualiza con setMinter()
     *      una vez que el Marketplace está deployado.
     * @param initialMinter Dirección autorizada a mintear tokens.
     */
    constructor(address initialMinter)
        ERC721("ArtChain NFT", "ARTNFT")
        Ownable(msg.sender)
    {
        if (initialMinter == address(0)) revert ZeroAddress();
        minter = initialMinter;
    }

    // ── External functions ────────────────────────────────────────────────────

    /**
     * @notice Mintea un nuevo NFT y se lo entrega a `to`.
     * @dev Solo puede ser llamado por la dirección `minter`.
     *      Interacción cross-contract: es invocado por ArtMarketplace.createNFT().
     * @param to Dirección que recibirá el NFT recién minteado.
     * @param uri URI de metadata IPFS del token (formato: ipfs://CID).
     * @return tokenId El ID del token creado.
     */
    function mint(address to, string calldata uri)
        external
        onlyMinter
        returns (uint256 tokenId)
    {
        tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        emit NFTMinted(to, tokenId, uri);
    }

    /**
     * @notice Actualiza la dirección del minter autorizado.
     * @dev Solo el owner puede llamarlo. Se usa para apuntar al Marketplace deployado.
     * @param newMinter Nueva dirección a autorizar como minter.
     */
    function setMinter(address newMinter) external onlyOwner {
        if (newMinter == address(0)) revert ZeroAddress();
        emit MinterUpdated(minter, newMinter);
        minter = newMinter;
    }

    // ── View functions ────────────────────────────────────────────────────────

    /**
     * @notice Devuelve la cantidad total de NFTs minteados hasta ahora.
     * @return Total de tokens emitidos.
     */
    function totalMinted() external view returns (uint256) {
        return _nextTokenId;
    }
}
