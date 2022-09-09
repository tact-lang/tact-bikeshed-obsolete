// WARNING: it may contains logic errors.

let JettonAmount = newtype(Coins);

interface JettonOwner {
    internal notify_transfer#7362d09c(
        query_id: Uint64,
        amount: JettonAmount,
        from: Address,
        payload: Either[RestSlice, Cell],
    );
}

interface ResponseReceiver {
    internal excesses#d53276db(query_id: Uint64);
}

interface Master {
    internal receive_burn_notification#d53276db(
        query_id: Uint64,
        amount: JettonAmount,
        from: JettonOwner,
        response_address: Address,
    );
}

interface Jetton {
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

    internal send_tokens#0f8a7ea5(
        query_id: Uint64,
        amount: JettonAmount,
        destination: Address,
        response_destination: Address,
        custom_payload: Maybe[Cell],
        forward_ton_amount: Coins,
        forward_payload: Either[RestSlice, Cell],
    );
    internal receive_tokens#178d4519(
        query_id: Uint64,
        amount: JettonAmount,
        from: Address,
        response_address: MaybeAddress,
        forward_ton_amount: Coins,
        forward_payload: Either[RestSlice, Cell],
    );
    internal burn_tokens#595f07bc(query_id: Uint64, burn_amount: JettonAmount, response_destination: Address);
}
