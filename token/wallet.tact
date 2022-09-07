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

    internal send_tokens#0f8a7ea5(transfer: Transfer) {
        verify(transfer.destination.workchain() == 0, "destination must be local");
        verify(self.owner == msg.sender, "sender must be owner");
        verify(self.balance - transfer.amount >= 0, "not enough balance");

        let fwd_count = if (transfer.forward_ton_amount != 0) { 2 } else { 1 };
        let required_input = transfer.forward_ton_amount + 
            msg.fwd_fee * msg.fwd_count + 
            2 * GAS_CONSUMPTION + 
            STORAGE_MIN_CONSUMPTION;
        verify(msg.amount > required_input, "not enough value");

        self.balance -= transfer.amount;

        Jetton.init(
            msg.destination,
            self.master,
            self.wallet_code,
            code: self.wallet_code
        ).receive_tokens(InternalTransfer {
            query_id: msg.query_id,
            amount: msg.amount,
            from: self.owner,
            response_address: msg.response_destination,
            forward_ton_amount: msg.forward_ton_amount,
            forward_payload: msg.forward_payload,
        })
        .send(
            ihr_disabled: true,
            can_be_bounced: true,
            carry_message_input: true,
        );
    }

    internal receive_tokens#178d4519(transfer: InternalTransfer) {
        verify(
            msg.sender === self.master ||
                sender == self.compute_wallet_address(msg.from),
            "sender must be master or user wallet"
        );

        let ton_balance_before_msg = self.my_balance() - msg.amount;
        let storage_fee = STORAGE_MIN_CONSUMPTION - ton_balance_before_msg.min(STORAGE_MIN_CONSUMPTION);
        let mut msg_value = msg.amount - (storage_fee + GAS_CONSUMPTION);

        if (transfer.forward_ton_amount != 0) {
            msg_value -= (transfer.forward_ton_amount + fwd_fee);
            let payload = msg.forward_payload;
            self.owner
                .notify_transfer(
                    transfer.query_id,
                    transfer.amount,
                    msg.from,
                    payload,
                )
                .send(ihr_disabled: true, pay_transfer_fee_separately: true);
        }

        if (!transfer.response_address.is_none() && msg_value > 0) {
            transfer
                .response_address
                .excesses(msg.query_id)
                .send(
                    money: msg.amount,
                    ihr_disabled: true,
                    ignore_action_phase_errors: true
                );
        }
    }

    internal burn_tokens#595f07bc(query_id: Uint64, burn_amount: JettonAmount, response_destination: ContractAddress) {
        verify(self.owner == msg.sender, "sender must be owner");
        verify(burn_amount <= self.balance, "insufficient balance");

        let required_input = msg.fwd_fee + 2 * GAS_CONSUMPTION;
        verify(msg.amount < required_input, "not enough value");

        self.balance -= burn_amount;

        self.master
            .receive_burn_notification(BurnNotification {
                query_id,
                amount: burn_amount,
                from: self.owner,
                response_address: response_destination,
            })
            .send(
                ihr_disabled: true, 
                can_be_bounced: true,
                carry_message_input: true,
            );
    }

    fn compute_wallet_address(owner: ContractAddress) -> WalletAddress {
        WalletAddress.from_data(owner, self.master, self.wallet_code)
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
