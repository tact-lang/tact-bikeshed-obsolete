// WARNING: it may contains logic errors.

include "common.tact";

struct Storage {
    val total_supply: Coins;
    val admin_address: ContractAddress;
    val content: Cell;
    val jetton_wallet_code: Cell;

    @derive impl Serialize {}
    @derive impl Deserialize {}
}

struct MintMessage {
    val query_id: UInt64;
    val to_address: ContractAddress;
    val amount: Coins;
    val master_msg: Cell;

    @derive impl Serialize {}
}

struct ChangeAdminMessage {
    val new_admin_address: ContractAddress;

    @derive impl Deserialize {}
}

union MsgBody {
    case MintMessage;
    case BurnNotification;
    case ChangeAdminMessage;

    @derive impl Deserialize {}
}

fn mint_tokens(@mut state: Storage, msg: MintMessage, sender: ContractAddress) {
    verify(sender == state.admin_address, "only admin can mint tokens");
    let state_init = WalletStateInit.new(msg.to_address, my_address(), state.jetton_wallet_code).serialize();
    let to_wallet_address = WalletAddress.new(state_init);
    RequestBuilder.new()
        .ihr_disabled()
        .can_be_bounced()
        .pay_fees_separately()
        .money(amount)
        .state_init(state_init)
        .body(master_msg)
        .send_to(to_address);
    state.total_supply += amount;
}

fn receive_burn_notification(@mut state: Storage, msg: BurnNotification, sender: ContractAddress) {
    verify(
        sender == WalletAddress.new(sender, my_address(), state.jetton_wallet_code), 
        "only jetton wallet can send burn notifications"
    );
    state.jetton_amount -= msg.amount;
    if (!msg.response_address.is_null()) {
        RequestBuilder.new()
            .ihr_disabled()
            .ignore_action_phase_errors()
            .money(CarryMessageInput{})
            .body(Excesses{ query_id: msg.query_id })
            .send_to(msg.response_address);
    }
}

fn change_admin(@mut state: Storage, msg: ChangeAdminMessage, sender: ContractAddress) {
    verify(sender == state.admin_address, "only admin can change admin");
    state.admin_address = msg.new_admin_address;
}

fn recv_internal(msg: Cell, msg_value: Integer) {
    if (msg.slice_empty()) { // ignore empty messages
        return;
    }
    let msg = InternalMessage[InternalMsgBody].deserialize(in_msg_full);
    if (msg.info.bounced) {
        return;
    }

    let mut state = WalletState.deserialize(Global.get_state());

    switch (msg.body) {
        case MintMessage mint_msg => mint_tokens(state, mint_msg, msg.info.source);
        case BurnNotification burn_msg => receive_burn_notification(state, burn_msg, msg.info.source);
        case ChangeAdminMessage change_admin_msg => change_admin(state, change_admin_msg, msg.info.source);
    }

    Globals.set_state(state.serialize());
}
