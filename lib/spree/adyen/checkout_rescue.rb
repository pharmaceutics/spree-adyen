module Spree
  module Adyen
    module CheckoutRescue
      extend ActiveSupport::Concern

      included do
        rescue_from Adyen::Enrolled3DError, :with => :rescue_from_adyen_3d_enrolled

        def rescue_from_adyen_3d_enrolled(exception)
          @adyen_3d_response  = exception
          crypt = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base)
          @enc_payment_number = crypt.encrypt_and_sign(exception.gateway_options[:payment_number])
          render 'spree/checkout/adyen_3d_form'
        end

        rescue_from Adyen::HPPRedirectError, :with => :rescue_from_adyen_hpp_redirect

        def rescue_from_adyen_hpp_redirect(exception)

          payment = exception.source.payments.processing.last
          @payment_order = payment.order

          redirect_params = {
            currency_code:      @payment_order.currency,
            ship_before_date:   Date.tomorrow,
            session_validity:   10.minutes.from_now,
            recurring:          false,
            merchant_reference: "#{@payment_order.number}-#{payment.number}",
            merchant_account:   exception.source.payment_method.merchant_account,
            skin_code:          exception.source.payment_method.skin_code,
            shared_secret:      exception.source.payment_method.shared_secret,
            payment_amount:     (payment.amount * 100).to_i,
            brandCode:          exception.source.brand_code
          }

          redirect_params[:resURL] = adyen_confirmation_url

          # TODO: For completeness offer configuration to render a view that will auto POST this information rather than a GET request
          redirect_to ::Adyen::Form.redirect_url(@redirect_params.merge(redirect_params))
        end

      end
    end
  end
end
