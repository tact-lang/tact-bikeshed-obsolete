// WARNING: it may contains logic errors.

include "common.tact";

struct Storage {
    val total_supply: Coins;
    val mintable: Bool;
    val admin_address: ContractAddress;
    val content: Cell;
    val jetton_wallet_code: Cell;

    @derive impl Serialize {}
    @derive impl Deserialize {}
}

contract JettonMinter {
    var total_supply: Coins;
    var admin_address: ContractAddress;
    var content: Cell;
    var jetton_wallet_code: Cell;

    init(admin_address: ContractAddress, content: Cell, jetton_wallet_code: Cell) {
        self.total_supply = 0;
        self.admin_address = admin_address;
        self.content = content;
        self.jetton_wallet_code = jetton_wallet_code;
    }

    bounced default() {
        // ignore bounced messages
    }

    internal mint#15(query_id: Uint64, to: Address, amount: JettonAmount, master_msg: Cell) {
        verify(msg.sender == self.owner, "only owner can mint tokens");

        send(PayFee) 
            Jetton.init(to, self.address(), self.jetton_wallet_code)
                .raw_message(master_msg, msg.amount: amount);

        self.total_supply += amount;
    }

    internal burn#595f07bc(query_id: Uint64, amount: JettonAmount, response_address: MaybeAddress) {
        verify(
            msg.sender == self.wallet_address(msg.sender), 
            "only jetton wallet can send burn notifications"
        );
        self.total_supply -= amount;
        if (!response_address.is_none()) {
            send(IgnoreErrors + InboundCoins) 
                response_address
                    .excesses(query_id)
                    .send_to(response_address);
        }
    }

    internal change_admin#3(new_admin_address: ContractAddress) {
        verify(msg.sender == self.admin_address, "only admin can change admin");
        self.admin_address = new_admin_address;
    }

    internal change_content#4(new_content: Cell) {
        verify(msg.sender == self.admin_address, "only admin can change content");
        self.content = new_content;
    }

    fn wallet_address(owner: Address) -> Address {
        Jetton.init(owner, self.address(), self.jetton_wallet_code).address()
    }

    get get_data() -> Storage {
        Storage {
            total_supply: self.total_supply,
            mintable: true,
            admin_address: self.admin_address,
            content: self.content,
            jetton_wallet_code: self.jetton_wallet_code
        }
    }

    get get_wallet_address(owner: Address) -> Address {
        self.wallet_address(owner)
    }
}
