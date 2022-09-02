// WARNING: it may contains logic errors.

struct WalletStateInit {
    val _unused1: Uint[2]; // split_depth and special
    val code: Maybe[RefCell];
    val data: Maybe[Ref[WalletData]];
    val _unused2: Uint[1]; // libraries

    fn new(owner: ContractAddress, master: ContractAddress, code: Cell) -> Self {
        Self {
            _unused1: 0,
            code: code,
            data: WalletData {
                balance: 0,
                address: owner,
                master: master,
                wallet_code: code,
            },
            _unused2: 0,
        }
    }

    @derive impl Serialize {}
}

struct WalletAddress {
    val inner: Slice

    fn new(state_init: Cell) -> Self {
        let b = Builder.new().store_uint(4, 3);
        let b = workchain().serialize(b);
        let b = state_init.hash().serialize(b);
        let inner = Slice.parse(b.build());
        Self { inner: inner }
    }

    fn from_data(owner: ContractAddress, master: ContractAddress, code: Cell) -> Self {
        self.new(WalletStateInit.new(owner, master, code).serialize(Builder.new()).build())
    }
}

struct Transfer {
    val query_id: Uint64;
    val amount: Coins;
    val destination: ContractAddress;
    val response_destination: ContractAddress;
    val custom_payload: Maybe[Cell];
    val forward_ton_amount: Coins;
    val forward_payload: Either[RestSlice, Cell];

    @derive impl Deserialize {}
}

struct InternalTransfer {
    val query_id: Uint64;
    val amount: Coins;
    val from: ContractAddress;
    val response_address: ContractAddress;
    val forward_ton_amount: Coins;
    val forward_payload: Either[RestSlice, Cell];

    @derive impl Deserialize {}
}

struct Burn {
    val query_id: Uint64;
    val amount: Coins;
    val response_destination: ContractAddress;

    @derive impl Deserialize {}
}

struct TransferNotification {
    val query_id: Uint64;
    val amount: Coins;
    val from: ContractAddress;
    val payload: Either[RestSlice, Cell];

    @derive impl Serialize {}
}

struct Excesses {
    val query_id: Uint64;

    @derive impl Serialize {}
}

struct BurnNotification {
    val query_id: Uint64;
    val amount: Coins;
    val from: ContractAddress;
    val response_address: ContractAddress;

    @derive impl Serialize {}
}
