// WARNING: it may contains logic errors.

include "common.tact";

let STORAGE_MIN_CONSUMPTION = Coins.minitons(10000000); // 0.01 TON
let GAS_CONSUMPTION = Coins.minitons(10000000); // 0.01 TON

struct WalletState {
    val balance: Coins;
    val address: ContractAddress;
    val master: ContractAddress;
    val wallet_code: Cell;

    @derive impl Serialize {}
    @derive impl Deserialize {}
}

union InternalMsgBody {
    case Transfer;
    case InternalTransfer;
    case Burn;

    @derive impl Deserialize {}
}

fn send_tokens(@mut state: WalletState, msg: Transfer, sender: ContractAddress, msg_value: Coins, fwd_fee: Coins) {
    verify(msg.destination.workchain() == 0, "destination must be local");
    verify(state.owner == sender, "sender must be owner");
    verify(state.balance - msg.amount >= 0, "not enough balance");

    let fwd_count = if (forward_ton_amount != 0) { 2 } else { 1 };
    let required_input = msg.forward_ton_amount + 
        fwd_fee * fwd_count + 
        2 * GAS_CONSUMPTION + 
        STORAGE_MIN_CONSUMPTION;
    verify(msg_value > required_input, "not enough value");

    state.balance -= msg.amount;

    let address_state_init = WalletStateInit.new(msg.destination, state.master, state.wallet_code).serialize();
    let to_wallet_address = WalletAddress.new(address_state_init);

    RequestBuilder.new()
        .ihr_disabled()
        .can_be_bounced()
        .with_coins(CarryMessageInput{})
        .state_init_as_ref(address_state_init)
        .body_as_ref[InternalMsgBody](InternalTransfer {
            query_id: msg.query_id,
            amount: msg.amount,
            from: state.owner,
            response_address: msg.response_destination,
            forward_ton_amount: msg.forward_ton_amount,
            forward_payload: msg.forward_payload,
        })
        }.serialize())
        .send_to(to_wallet_address);
}

fn receive_tokens(
    @mut state: WalletState, 
    msg: InternalTransfer, 
    sender: ContractAddress, 
    my_ton_balance: Coins, 
    fwd_fee: Coins, 
    msg_value: Coins
) {
    verify(
        sender === state.master || 
            sender == WalletAddress.from_data(msg.from, state.master, state.wallet_code), 
        "sender must be master or user wallet"
    );

    let ton_balance_before_msg = my_ton_balance - msg_value;
    let storage_fee = STORAGE_MIN_CONSUMPTION - ton_balance_before_msg.min(STORAGE_MIN_CONSUMPTION);
    let @mut msg_value = msg_value - (storage_fee + GAS_CONSUMPTION);

    if (forward_ton_amount != 0) {
        msg_value -= (forward_ton_amount + fwd_fee);
        let payload = msg.forward_payload;
        RequestBuilder.new()
            .ihr_disabled()
            .pay_transfer_fee_separately()
            .money(forward_ton_amount)
            .body(TransferNotification {
                query_id: msg.query_id,
                amount: msg.amount,
                from: msg.from,
                payload: payload,
            })
            .send_to(owner_address);
    }

    if (!response_address.is_null() && msg_value > 0) {
        RequestBuilder.new()
            .ihr_disabled()
            .ignore_action_phase_errors()
            .money(msg_value)
            .body(Excesses {
                query_id: msg.query_id,
            })
            .send_to(response_address);
    }
}

fn burn_tokens(
    @mut state: WalletState, 
    msg: Burn, 
    sender: ContractAddress, 
    msg_value: Coins
    fwd_fee: Coins, 
) {
    verify(state.owner == sender, "sender must be owner");
    verify(state.balance - msg.amount >= 0, "not enough balance");

    let required_input = fwd_fee + 2 * GAS_CONSUMPTION;
    verify(msg_value > required_input, "not enough value");

    state.balance -= msg.amount;

    RequestBuilder.new()
        .ihr_disabled()
        .can_be_bounced()
        .with_coins(CarryMessageInput{})
        .body_as_ref[InternalMsgBody](BurnNotification {
            query_id: msg.query_id,
            amount: msg.amount,
            from: state.owner,
            response_address: msg.response_destination,
        })
        .send_to(state.master);
}

fn on_bounce(
    @mut state: WalletState,
    body: Slice
) {
    let op = body.load_uint(32);
    verify(op == InternalTransfer || op == BurnNotification, "invalid bounce operation");

    let query_id = body.load_uint(64);
    let jetton_amount = body.load_coins();
    state.balance += jetton_amount;
}

fn recv_internal(my_balance: Coins, msg_value: Coins, in_msg_full: Cell) {
    if (in_msg_body.slice_empty()) { // ignore empty messages
        return;
    }
    let msg = InternalMessage[InternalMsgBody].deserialize(in_msg_full);
    if (msg.info.bounced) {
        on_bounce(msg.body);
        return;
    }

    let mut state = WalletState.deserialize(Global.get_state());

    switch (msg.body) {
        Transfer => send_tokens(state, msg.body, msg.info.sender, msg_value, msg.info.fwd_fee);
        InternalTransfer => receive_tokens(state, msg.body, msg.info.sender, my_balance, msg.info.fwd_fee, msg_value);
        Burn => burn_tokens(state, msg.body, msg.info.sender, msg_value, msg.info.fwd_fee);
    }

    Globals.set_state(state.serialize());
}
