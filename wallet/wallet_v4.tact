interface Plugin {
    internal requested_funds#f06c7567(query_id: Uint64);
    internal notify_removed#e4737472(query_id: Uint64);
    internal notify_installed#6e6f7465(query_id: Uint64);
    internal notify_removed#64737472(query_id: Uint64);
}

contract Wallet {
    var seqno: Uint32
    var subwallet: Uint32
    var pubkey: Pubkey
    var plugins: Set[Plugin]

    bounced default() {
        // ignore bounced messages
    }

    internal default() {
        // ignore simple transfers
    }

    internal request_funds#706c7567(
        query_id: Uint64,
        requested_amount: Coins,
        requested_extra: ExtraCurrencies,
        msg.sender: Plugin,
    ) {
        if !this.plugins.contains(msg.sender) {
            return;
        }
        // We subtract the incoming amount because it's already included in the balance
        // and we are sending it back alongside the requested_amount.
        verify(requested_amount <= self.balance()-msg.amount, "Not enough funds");

        send(InboundCoins)
        msg.sender.requested_funds(
            query_id,
            msg.amount: requested_amount,
            msg.extra: requested_extra,
        );
    }

    internal remove_plugin#64737472(query_id: Uint64, msg.sender: Plugin) {
        if !this.plugins.contains(msg.sender) {
            return;
        }
        self.plugins.remove(msg.sender);

        if msg.bounceable {
            send(InboundCoins) msg.sender.notify_removed(query_id);
        }
    }

    external pre_condition(body: Slice) -> Slice {
        let sig = body.read(Signature);
        if sig.verify(body, self.pubkey) {
            self.accept();
            self.seqno += 1;
            self.commit();
            return body;
        } else {
            thrown("Invalid signature");
        }
    }

    external simple_transfer#00(messages: List[(Cell, Sendmode)]) -> Slice {
        for (msg, flags) in messages {
            send_raw_msg(msg, flags);
        }
    }

    external deploy_and_install_plugin#1(
        workchain: Int8,
        balance: Coins,
        state_init: Ref[StateInit],
        body: Cell,
    ) {
        let address = AddressStd.new(workchain, state_init.hash());

        send(PayFee + IgnoreErrors)
            address.send_raw(
                body,
                msg.amount: balance,
                msg.state_init: state_init,
            );

        self.plugins.insert(address);
    }

    external install_plugin#02(plugin: Plugin, amount: Coins, query_id: Uint64) {
        self.plugins.insert(plugin);
        send(PayFee + IgnoreErrors) plugin.notify_installed(query_id, msg.amount: balance);
    }

    external remove_plugin#03(plugin: Plugin, query_id: Uint64) {
        self.plugins.remove(plugin);
        send(PayFee + IgnoreErrors) plugin.notify_removed(query_id);
    }
}