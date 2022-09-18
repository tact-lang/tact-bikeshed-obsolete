// WARNING: it may contains logic errors.

include "common.tact";

let STORAGE_MIN_CONSUMPTION = Coins.millitons(10); // 0.01 TON
let GAS_CONSUMPTION = Coins.millitons(10); // 0.01 TON

struct WalletData {
    var balance: JettonAmount;
    var owner: JettonOwner;
    var master: Master;
    var wallet_code: Cell;
}

contract JettonImpl: Jetton {
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

    bounced transfer#0f8a7ea5(body: Transfer) {
        self.balance += body.amount;
    }

    internal send_tokens#0f8a7ea5(
        query_id: Uint64,
        jetton_amount: JettonAmount,
        destination: Address,
        response_destination: Address,
        custom_payload: Maybe[Cell],
        forward_ton_amount: Coins,
        forward_payload: Either[RestSlice, Cell],
    ) {
        verify(destination.workchain() == 0, "destination must be local");
        verify(self.owner == msg.sender, "sender must be owner");
        verify(self.balance - jetton_amount >= 0, "not enough balance");

        let fwd_count = if (forward_ton_amount != 0) { 2 } else { 1 };
        let required_input = forward_ton_amount + 
            msg.fwd_fee * msg.fwd_count + 
            2 * GAS_CONSUMPTION + 
            STORAGE_MIN_CONSUMPTION;
        verify(msg.amount > required_input, "not enough value");

        self.balance -= jetton_amount;

        send(InboundCoins) Jetton.init(
            msg.destination,
            self.master,
            self.wallet_code,
            code: self.wallet_code
        ).receive_tokens(
            query_id,
            amount: jetton_amount,
            from: self.owner,
            response_address: response_destination,
            forward_ton_amount,
            forward_payload,
        );
    }

    internal receive_tokens#178d4519(
        query_id: Uint64,
        jetton_amount: JettonAmount,
        from: Address,
        response_address: MaybeAddress,
        forward_ton_amount: Coins,
        forward_payload: Either[RestSlice, Cell],
    ) {
        verify(
            msg.sender === self.master ||
                sender == self.compute_wallet_address(msg.from),
            "sender must be master or user wallet"
        );

        let ton_balance_before_msg = self.my_balance() - msg.amount;
        let storage_fee = STORAGE_MIN_CONSUMPTION - ton_balance_before_msg.min(STORAGE_MIN_CONSUMPTION);
        let mut msg_value = msg.amount - (storage_fee + GAS_CONSUMPTION);

        if (forward_ton_amount != 0) {
            msg_value -= (forward_ton_amount + fwd_fee);
            let payload = msg.forward_payload;
            send(PayFee)
            self.owner
                .notify_transfer(
                    query_id,
                    jetton_amount,
                    msg.from,
                    payload,
                    bounceable: false,
                );
        }

        if (!response_address.is_none() && msg_value > 0) {
            send(IgnoreErrors)
            response_address
                .excesses(
                    msg.query_id,
                    amount: msg.amount,
                    bounceable: false
                );
        }
    }

    internal burn_tokens#595f07bc(query_id: Uint64, burn_amount: JettonAmount, response_destination: Address) {
        verify(self.owner == msg.sender, "sender must be owner");
        verify(burn_amount <= self.balance, "insufficient balance");

        let required_input = msg.fwd_fee + 2 * GAS_CONSUMPTION;
        verify(msg.amount < required_input, "not enough value");

        self.balance -= burn_amount;

        send(InboundCoins)
        self.master
            .receive_burn_notification(
                query_id,
                burn_amount,
                self.owner,
                response_destination,
            );
    }

    fn compute_wallet_address(owner: Address) -> Address {
        JettonImpl.init(owner, self.master, self.wallet_code).address()
    }

    get wallet_data() -> WalletData {
        WalletData {
            balance: self.balance,
            owner: self.owner,
            master: self.master,
            wallet_code: self.wallet_code,
        }
    }
}
