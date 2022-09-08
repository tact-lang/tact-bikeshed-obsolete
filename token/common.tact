// WARNING: it may contains logic errors.

let JettonAmount = newtype(Coins);

struct Transfer {
    val query_id: Uint64;
    val amount: JettonAmount;
    val destination: ContractAddress;
    val response_destination: ContractAddress;
    val custom_payload: Maybe[Cell];
    val forward_ton_amount: Coins;
    val forward_payload: Either[RestSlice, Cell];

    @derive impl Deserialize {}
}

struct InternalTransfer {
    val query_id: Uint64;
    val amount: JettonAmount;
    val from: ContractAddress;
    val response_address: ResponseReceiver;
    val forward_ton_amount: Coins;
    val forward_payload: Either[RestSlice, Cell];

    @derive impl Deserialize {}
}

contract interface JettonOwner {
    internal notify_transfer#7362d09c(
        query_id: Uint64,
        amount: JettonAmount,
        from: ContractAddress,
        payload: Either[RestSlice, Cell],
    );
}

contract interface ResponseReceiver {
    internal excesses#d53276db(query_id: Uint64);
}

contract interface Master {
    internal receive_burn_notification#d53276db(notification: BurnNotification);
}

contract interface Jetton {
    var balance: JettonAmount;
    var owner: JettonOwner;
    var master: Master;
    var wallet_code: Cell;

    init(owner: JettonOwner, master: Master, wallet_code: Cell) {
        self.balance = 0;
        self.owner = owner;
        self.master = master;
        self.wallet_code = wallet_code;
    }

    internal send_tokens#0f8a7ea5(body: Transfer);
    internal receive_tokens#178d4519(body: InternalTransfer);
    internal burn_tokens#595f07bc(query_id: Uint64, burn_amount: JettonAmount, response_destination: ContractAddress);
}
