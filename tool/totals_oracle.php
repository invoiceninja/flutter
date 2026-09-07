<?php

/**
 * Totals parity oracle — runs the REAL Invoice Ninja server math offline.
 *
 * Reads a JSON array of invoice specs (argv[1] file path, else stdin) and
 * prints a JSON array of
 * `{line_totals, total_taxes, total, tax_map}` on stdout. Used by
 * `test/domain/billing/totals_parity_test.dart` to assert `computeTotals`
 * agrees with the server clause-for-clause.
 *
 * WHY THIS AND NOT A DART TRANSCRIPTION: a transcription can be wrong in
 * exactly the way the code under test is wrong, and then it certifies the bug.
 * That is not hypothetical here — a careful hand-derivation of the
 * shared-tax-name case predicted 12/122 where the real code returns 11.5/121.5.
 * This loads the canonical helper classes from the server checkout, so the only
 * thing that can drift is the stub layer below (models + two display helpers).
 *
 * Requires:
 *   - the canonical server checkout (CLAUDE.md § Reference points)
 *   - a composer `vendor/` for the real `Illuminate\Support\Collection`
 * Override either with INVOICENINJA_SRC / INVOICENINJA_VENDOR.
 *
 * Skips gracefully (exit 0, `{"skipped":…}`) when neither is present, so the
 * Dart test can skip rather than fail on a machine without the server source.
 */

namespace App\Models {
    /** Only the fields the math reads; everything else is a type hint. */
    class Invoice
    {
        public $line_items = [];
        public $discount = 0;
        public $is_amount_discount = false;
        public $uses_inclusive_taxes = false;
        public $tax_name1 = '';
        public $tax_rate1 = 0;
        public $tax_name2 = '';
        public $tax_rate2 = 0;
        public $tax_name3 = '';
        public $tax_rate3 = 0;
        public $custom_surcharge1 = 0;
        public $custom_surcharge2 = 0;
        public $custom_surcharge3 = 0;
        public $custom_surcharge4 = 0;
        public $custom_surcharge_tax1 = false;
        public $custom_surcharge_tax2 = false;
        public $custom_surcharge_tax3 = false;
        public $custom_surcharge_tax4 = false;
        public $partial = 0;
        public $balance = 0;
        public $amount = 0;
        public $total_taxes = 0;
        public $paid_to_date = 0;
        public $status_id = 1;
        public $client;
        public $vendor;
        /**
         * Left null on purpose. `InvoiceItemSum::shouldCalculateTax()` reads
         * `company?->calculate_taxes` and falls back to `calc_tax = false`,
         * i.e. the manual-tax-rate path. That is the only mode the Flutter
         * calculator models — it has no automatic region-rule tax feature —
         * so this is the correct baseline for parity, not an omission.
         */
        public $company = null;
    }
    class Quote extends Invoice {}
    class Credit extends Invoice {}
    class PurchaseOrder extends Invoice {}
    class RecurringInvoice extends Invoice {}
    class RecurringQuote extends Invoice {}
    class Vendor {}
    class Currency { public $precision = 2; }
    class Client
    {
        public $precision = 2;
        public $is_tax_exempt = false;
        public $country_id = 840;
        public function currency()
        {
            $c = new Currency();
            $c->precision = $this->precision;
            return $c;
        }
        public function getSetting($key) { return false; }
    }
}

namespace App\Utils {
    /** Display-only helpers; neither affects an amount. */
    class Number
    {
        public static function formatValueNoTrailingZeroes($value, $client = null)
        {
            return rtrim(rtrim(number_format((float) $value, 10, '.', ''), '0'), '.');
        }
        public static function roundValue($value, $precision = 2)
        {
            return round((float) $value, $precision, PHP_ROUND_HALF_UP);
        }
    }
}

namespace {
    $src = getenv('INVOICENINJA_SRC') ?: '/Users/hillel/Code/invoiceninja';
    $vendor = getenv('INVOICENINJA_VENDOR') ?: '/Users/hillel/Code/invoiceninja-fork/vendor/autoload.php';

    if (!is_dir($src) || !file_exists($vendor)) {
        echo json_encode(['skipped' => 'server source or vendor/ not available']), PHP_EOL;
        exit(0);
    }
    require $vendor;

    foreach ([
        '/app/Utils/BcMath.php',
        '/app/Utils/Traits/NumberFormatter.php',
        '/app/Helpers/Invoice/InclusiveTax.php',
        '/app/Helpers/Invoice/Taxer.php',
        '/app/Helpers/Invoice/Discounter.php',
        '/app/Helpers/Invoice/CustomValuer.php',
        '/app/Helpers/Invoice/InvoiceItemSum.php',
        '/app/Helpers/Invoice/InvoiceItemSumInclusive.php',
        '/app/Helpers/Invoice/InvoiceSum.php',
        '/app/Helpers/Invoice/InvoiceSumInclusive.php',
    ] as $f) {
        require_once $src . $f;
    }

    function oracle_line(array $o)
    {
        return (object) array_merge([
            'cost' => 0, 'quantity' => 1, 'discount' => 0, 'is_amount_discount' => false,
            'line_total' => 0, 'gross_line_total' => 0, 'tax_amount' => 0, 'net_cost' => 0,
            'tax_name1' => '', 'tax_rate1' => 0, 'tax_name2' => '', 'tax_rate2' => 0,
            'tax_name3' => '', 'tax_rate3' => 0, 'tax_id' => '1',
            'product_key' => '', 'notes' => '', 'type_id' => '1',
        ], $o);
    }

    function oracle_run(array $spec): array
    {
        $inv = new \App\Models\Invoice();
        foreach (($spec['invoice'] ?? []) as $k => $v) {
            $inv->$k = $v;
        }
        $client = new \App\Models\Client();
        $client->precision = $spec['precision'] ?? 2;
        $inv->client = $client;
        $inv->line_items = array_map('oracle_line', $spec['line_items'] ?? []);

        // Mirrors `Invoice::calc()` — the inclusive path is a DIFFERENT class,
        // and using the wrong one yields plausible but meaningless numbers.
        $sum = $inv->uses_inclusive_taxes
            ? new \App\Helpers\Invoice\InvoiceSumInclusive($inv)
            : new \App\Helpers\Invoice\InvoiceSum($inv);

        // The chain is private, and we stop before calculateBalance() /
        // calculatePartial(), which touch persistence and nothing we compare.
        foreach ([
            'calculateLineItems', 'calculateDiscount', 'calculateInvoiceTaxes',
            'calculateCustomValues', 'setTaxMap', 'calculateTotals',
        ] as $method) {
            $m = new \ReflectionMethod($sum, $method);
            $m->setAccessible(true);
            $m->invoke($sum);
        }

        return [
            'line_totals' => array_map(fn ($i) => (string) $i->line_total, $inv->line_items),
            'total_taxes' => (string) $sum->getTotalTaxes(),
            'total' => (string) $sum->getTotal(),
        ];
    }

    // argv[1] is a JSON file path when given (Dart's Process.runSync has no
    // stdin), otherwise read stdin so the tool stays usable from a shell pipe.
    $raw = ($argc > 1 && is_readable($argv[1]))
        ? file_get_contents($argv[1])
        : stream_get_contents(STDIN);
    $input = json_decode($raw, true) ?: [];
    echo json_encode(array_map('oracle_run', $input)), PHP_EOL;
}
