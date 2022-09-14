interface Plugin {
    internal requested_funds#f06c7567(query_id: Uint64);
    internal notify_removed#e4737472(query_id: Uint64);
    internal notify_installed#6e6f7465(query_id: Uint64);
    internal notify_removed#64737472(query_id: Uint64);
}

interface Wallet {
    internal request_funds#706c7567(
        query_id: Uint64,
        requested_amount: Coins,
        requested_extra: ExtraCurrencies,
        msg.sender: Plugin,
    );
    internal remove_plugin#64737472(query_id: Uint64, msg.sender: Plugin);
}

interface Beneficiary {
    internal destruct#64737472(msg.sender: Plugin);
    internal fallback#756e6b77(msg.sender: Plugin);
    internal subscription#73756273(msg.sender: Plugin);
}

contract SubscriptionPlugin: Plugin {
    var wallet: Wallet;
    var benefeciary: Beneficiary;
    var amount: Coins;
    var period: Uint32;
    var start_time: Uint32;
    var timeout: Uint32;
    var last_payment_time: Uint32;
    var last_request_time: Uint32;
    var failed_attempts: Uint8;
    var subscription_id: Uint32;

    internal default() {
        send(CarryMessageBalance) 
        self.beneficiary.fallback(
            msg.bounceable: false,
            msg.extra: self.extra(),
        );
    }

    internal destruct#0x64737472(query_id: Uint64) {
        if msg.sender == self.benefeciary {
            let amount_gas = Gas.units(10_000, workchain: self.wallet.workchain());

            send(InboundCoins + IgnoreErrors)
            self.wallet.remove_plugin(
                self.logical_time(),
                msg.gas: amount_gas,
                msg.bounceable: false,
            );

            self.reserve_at_most(Coins.nanotons(67_108_864));

            send(DestructSelf)
            self.benefeciary.destruct(
                msg.bounceable: false,
                msg.extra: self.extra(),
            );
        } else if msg.sender == self.wallet {
            send(DestructSelf)
            self.benefeciary.destruct(
                msg.bounceable: false,
                msg.extra: self.extra(),
            );
        } else {
            send(CarryMessageBalance) 
            self.benefeciary.fallback(
                msg.bounceable: false,
                msg.extra: self.extra(),
            );
        }
    }

    internal destruct#0x64737472(query_id: Uint64) {
        verify(msg.sender == benefeciary, "Only benefeciary can destroy the subscription");

        let amount_gas = Gas.units(10_000, workchain: self.wallet.workchain());

        send(InboundCoins + IgnoreErrors) 
        self.wallet.remove_plugin(
            self.logical_time(),
            msg.gas: amount_gas,
            msg.bounceable: false,
        );

        send(DestructSelf) 
        self.benefeciary.destruct(
            msg.bounceable: false,
            msg.extra: self.extra(),
        );
    }

    internal forward_funds#??????() {
        self.reserve_at_most(Coins.nanotons(67_108_864));
        
        send(CarryMessageBalance) 
        self.benefeciary.fallback(
            msg.bounceable: false,
            msg.extra: self.extra(),
        );
    }

    internal requested_funds#f06c7567(query_id: Uint64) {
        let last_timeslot = (self.last_payment_time - self.start_time) / self.period;
        let cur_timeslot = (self.now() - self.start_time) / self.period;
        verify(last_timeslot < cur_timeslot, "Last payment time is greater than current time");
            
        let fwd_fee = self.blockchain(msg.sender.wc()).short_msg_fwd_fee();
        if (msg.amount >= self.amount - fwd_fee) {
            self.last_payment_time = self.now();
            self.failed_attempts = 0;

            send(CarryMessageBalance) 
            self.benefeciary.subscription(
                msg.bounceable: false,
                msg.extra: self.extra(),
            );
        }
    }

    external default() {
        let last_timeslot = (self.last_payment_time - self.start_time) / self.period;
        let cur_timeslot = (self.now() - self.start_time) / self.period;

        // throw_unless(30, (cur_timeslot > last_timeslot) & (last_request_time + timeout < now())); ;; too early request

        verify(last_timeslot < cur_timeslot, "Last payment time is greater than current time");
        self.accept();

        if self.failed_attempts >= 3 {
            let amount_gas = Gas.units(10_000, workchain: self.wallet.workchain());

            send(InboundCoins + IgnoreErrors)
            self.wallet.remove_plugin(
                self.logical_time(),
                msg.gas: amount_gas,
                msg.bounceable: false,
            );

            self.reserve_at_most(Coins.nanotons(67_108_864));

            send(DestructSelf)
            self.benefeciary.destruct(
                msg.bounceable: false,
                msg.extra: self.extra(),
            );
        } else {
            let amount_gas = Gas.units(15_000, workchain: self.wallet.workchain())
                + self.blockchain(msg.sender.wc()).short_msg_fwd_fee();
            send(InboundCoins + IgnoreErrors) 
            self.wallet.request_funds(
                self.logical_time(),
                self.amount,
                ExtraCurrencies.zero(),
                msg.gas: amount_gas,
            );
            self.failed_attempts += 1;
        }
    }

    get subscription_data() -> Self.Storage {
        Self.Storage(
            wallet: self.wallet,
            benefeciary: self.benefeciary,
            amount: self.amount,
            period: self.period,
            start_time: self.start_time,
            timeout: self.timeout,
            last_payment_time: self.last_payment_time,
            last_request_time: self.last_request_time,
            failed_attempts: self.failed_attempts,
            subscription_id: self.subscription_id,
        )
    }
}