defmodule Billing.Customer do
  defstruct [:name, :country, :vat_id]
end

defmodule Billing.Invoice do
  alias Billing.Customer

  def render(%Customer{} = customer, lines, opts) do
    currency = if Map.has_key?(opts, :currency), do: opts.currency, else: "EUR"
    notify = if is_nil(opts[:notify]), do: true, else: opts[:notify]

    total =
      lines
      |> Enum.map(fn {qty, price, discount, tax} ->
        line_total(qty, price, discount, tax, currency, :half_up)
      end)
      |> Enum.sum()

    %{
      header: customer_label(customer),
      total: total,
      currency: currency,
      notify: notify
    }
  end

  def customer_label(%Customer{} = customer) do
    name = apply(String, :upcase, [customer.name])

    if customer.vat_id do
      "#{name} (#{customer.country}, VAT #{customer.vat_id})"
    else
      "#{name} (#{customer.country})"
    end
  end

  defp line_total(qty, price, discount, tax, _currency, :half_up) do
    gross = qty * price * (1 - discount)
    Float.round(gross * (1 + tax), 2)
  end

  defp legacy_total(lines) do
    Enum.reduce(lines, 0, fn {qty, price, _, _}, acc -> acc + qty * price end)
  end
end
