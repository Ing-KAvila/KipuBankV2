**KipuBank** es un contrato de custodia multi-token que permite a los usuarios:
Depositar y retirar ETH o tokens ERC-20.
Mantener sus fondos en una bóveda personal.
Operar bajo límites seguros definidos en USD, gracias a Chainlink.

**KipuBankV2**
El contrato KipuBankV2 representa una evolución significativa respecto a la versión anterior. Las mejoras se centran en seguridad, escalabilidad, interoperabilidad y control administrativo, con los siguientes cambios clave:
   - Se amplía el soporte para ERC-20 tokens, permitiendo depósitos y retiros en múltiples activos.
   - Se usa SafeERC20 para transferencias seguras, evitando errores comunes con tokens no estándar.
   - Se reemplazan los límites en ETH por límites en USD, usando Chainlink ETH/USD price feed.
   - Se integran ReentrancyGuard y Pausable para proteger contra ataques y permitir pausas operativas.
   - Se aplican modificadores personalizados para validar límites antes de ejecutar transferencias.
   - Se añade Ownable para permitir funciones exclusivas del propietario como recuperación de tokens y control de pausado.
   - Se implementa recoverToken() para mitigar errores de envío accidental.

**Decisiones de diseño importantes**
   - Uso de Chainlink: permite límites dinámicos basados en USD, más intuitivos para usuarios.
   - Modularidad con interfaces y librerías: facilita auditoría, mantenimiento y escalabilidad.
   - Eventos bien definidos: trazabilidad clara en block explorers.

**Trade-offs considerados**
   - Conversión simplificada para tokens: se asume 1:1 con USD para tokens estables, lo cual es eficiente pero puede ser impreciso para tokens volátiles.
   - No se incluye array de tokens rastreados: evita gas extra, pero limita el cálculo total de USD si se usan múltiples tokens.
   - Uso de call para ETH: más flexible que transfer, pero requiere manejo explícito de errores.

Este contrato es ideal para plataformas que manejan múltiples activos y aplicaciones DeFi que requieren límites dinámicos.


**Funcionalidades principales**
1. Depósitos
Los usuarios pueden depositar:
ETH directamente (depositETH() o enviando ETH al contrato).
Tokens ERC-20 mediante depositToken(token, amount).

2. Retiros
Los usuarios pueden retirar:
ETH con withdrawETH(amount).
Tokens con withdrawToken(token, amount).

3. Límites en USD
Se definen dos límites:
Límite global del banco (bankCapUsd): máximo total permitido en la bóveda.
Límite por transacción (withdrawalLimitUsd): máximo que se puede retirar por operación.
Se usa Chainlink ETH/USD para convertir montos a USD.
Para tokens ERC-20, se asume una equivalencia 1:1 con USD (útil para stablecoins).

4. Seguridad
Todas las funciones sensibles usan nonReentrant y whenNotPaused.
Usa ReentrancyGuard para evitar ataques de reentrada.
Usa Pausable para detener operaciones en caso de emergencia.
Usa Ownable para que el propietario pueda:
     Pausar/despausar el contrato.
     Recuperar tokens enviados por error.
Se validan límites antes de ejecutar transferencias.
Se usan errores personalizados para claridad y ahorro de gas.
Se usa SafeERC20 para evitar fallos con tokens no estándar.

5. Eventos y trazabilidad
Emite eventos Deposited y Withdrawn para cada operación.
Permite rastrear depósitos totales por token y por usuario.

**Instrucciones de interacción**
depositETH(): enviar ETH directamente o llamar la función.
depositToken(token, amount): aprobar primero el contrato, luego llamar.
withdrawETH(amount): retira ETH si cumple el límite y saldo.
withdrawToken(token, amount): retira tokens ERC-20.
recoverToken(token, to, amount): solo el owner puede recuperar fondos.
pause() / unpause(): control de emergencia por el owner.


**Instrucciones de despliegue del contrato**

**1. Parámetros del constructor**
Al desplegar el contrato, debes proporcionar:
address _ethUsdFeed: dirección del Chainlink ETH/USD price feed.
Ejemplo en Sepolia: 0x694AA1769357215DE4FAC081bf1f309aDC325306
uint256 _bankCapUsd: límite total del banco en USD (con 6 decimales).
Ejemplo: 100000000 para $100,000.00
uint256 _withdrawalLimitUsd: límite por transacción en USD (con 6 decimales).
Ejemplo: 5000000 para $5,000.00

*En Remix*
Copia el contrato en Remix.
Selecciona compilador Solidity 0.8.30.
Asegúrate de importar correctamente OpenZeppelin y Chainlink.
Despliega el contrato con los parámetros anteriores.

**2. Interacción con funciones**
  - Depositar ETH
    function depositETH() public payable
    *En Remix:* selecciona depositETH() y envía ETH en el campo "Value".

  - Depositar tokens ERC-20
    function depositToken(address token, uint256 amount) external
    Pasos:
    Asegúrate de que el usuario haya aprobado el contrato para mover sus tokens:
    IERC20(token).approve(address(KipuBank), amount);
    Llama a depositToken(token, amount).

  - Retirar ETH
    function withdrawETH(uint256 amount) external
    Verifica que el monto esté dentro del límite USD y que el usuario tenga saldo suficiente.
    Llama a la función y el contrato enviará ETH al usuario.

  - Retirar tokens ERC-20
    function withdrawToken(address token, uint256 amount) external
    Verifica que el token no sea address(0) y que el usuario tenga saldo.
    Llama a la función y el contrato transferirá los tokens.

  - Recuperar tokens (solo owner)
    function recoverToken(address token, address to, uint256 amount) external onlyOwner
    Útil si alguien envía tokens por error al contrato.
    El owner puede recuperar ETH o tokens y enviarlos a to.

  - Pausar y reanudar el contrato 
    function pause() external onlyOwner
    function unpause() external onlyOwner
    Pausar bloquea depósitos y retiros.
    Útil en caso de emergencia o mantenimiento.

**3. Consultas y utilidades**
  - Ver saldo de usuario
    vault[user][token]
    Consulta el saldo de un usuario para un token específico.
  - Ver precio ETH/USD
    getLatestEthUsdPrice()
    Devuelve el precio actual de ETH en USD (8 decimales).
  - Convertir monto a USD
    _convertToUsd(token, amount)
    Interna: convierte cualquier monto a USD según el tipo de token.

**4. Recomendaciones para pruebas**
Prueba depósitos y retiros con ETH y al menos dos tokens ERC-20 (uno estable y uno volátil).
Simula escenarios donde se exceden los límites para validar errores.
Verifica que los eventos Deposited y Withdrawn se emitan correctamente.
Prueba pausado y recuperación de tokens como owner.




**Ubicación: Buenos Aires, Argentina. Fecha: 25 de Octubre 2025**
