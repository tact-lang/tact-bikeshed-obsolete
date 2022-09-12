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
        verify(self.balance() - msg.amount >= requested_amount, "Not enough funds");

        send(InboundCoins)
        msg.sender.requested_funds(
            query_id,
            msg.amount: requested_amount,
            msg.extra: requested_extra,
        );
    }

    internal remove_plugin#64737472(query_id: Uint64, msg.sender: Plugin) {
        self.remove_plugin_from_list(msg.sender);

        if msg.bounceable {
            send(InboundCoins) msg.sender.notify_removed(query_id);
        }
    }

    external pre_condition(body: Slice) -> Slice {
        let sign = body.read(Signature);
        if sign.verify(body, self.pubkey) {
            self.accept();
            self.seqno += 1;
            self.commit();
            return body;
        } else {
            thrown("Invalid signature");
        }
    }

    external simple_transfer#0(messages: List[(Cell, Sendmode)]) -> Slice {
        for (msg, flags) in messages {
            send_raw_msg(msg, flags);
        }
    }

    external destroy_and_install_plugin#1(
        workchain: Int8,
        balance: Coins,
        state_init: Ref[StateInit],
        body: Cell,
    ) -> Slice {
        let address = AddressStd.new(workchain, state_init.hash());

        send(PayFee + IgnoreErrors)
            address.send_raw(
                body,
                msg.amount: balance,
                msg.state_init: state_init,
            );

        self.add_plugin(address);
    }

    external install_plugin#2(
        plugin: Plugin,
        amount: Coins,
        query_id: Uint64,
    ) -> Slice {
        let address = AddressStd.new(workchain, state_init.hash());

        self.add_plugin(address);

        send(PayFee + IgnoreErrors)
            plugin.notify_installed(
                query_id,
                msg.amount: balance,
            );
    }

    external remove_plugin#3(
        plugin: Plugin,
        query_id: Uint64,
    ) -> Slice {
        self.remove_plugin_from_list(plugin);

        send(PayFee + IgnoreErrors)
            plugin.notify_removed(
                query_id,
            );
    }

    fn get_plugin(addr: Address) -> Option[Plugin] {
        self.plugins.get(addr.to_std())
    }

    fn remove_plugin_from_list(addr: Address) {
        self.plugins.remove(addr.to_std())
    }

    fn add_plugin(addr: Address) {
        self.plugins.insert(addr.to_std())
    }
}