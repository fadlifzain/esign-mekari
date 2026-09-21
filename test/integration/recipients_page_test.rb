require "test_helper"

class RecipientsPageTest < ActionDispatch::IntegrationTest
  test "recipients page exposes an eMeterai stepper beside signatures" do
    get sign_recipients_url(workspace_id: "ws-a")

    assert_response :success
    assert_includes response.body, "eMeterai"
    assert_includes response.body, 'data-field="meterai_count"'
    assert_includes response.body, 'data-field="signature_count"'
    assert_includes response.body, "Signature"
    assert_includes response.body, "Total charge"
    assert_includes response.body, "Parallel"
    assert_includes response.body, "Sequential"
    assert_includes response.body, 'aria-label="Signing order"'
    assert_includes response.body, 'data-action="recipients#moveUp"'
    assert_includes response.body, 'data-action="recipients#moveDown"'
    assert_includes response.body, 'data-action="recipients#mergePrevious"'
    assert_includes response.body, 'data-action="recipients#mergeNext"'
    assert_includes response.body, "Join previous step"
    assert_includes response.body, "Parallel signer"
    assert_no_match(/sign-order"[^>]*style="display:\s*none/, response.body)
    assert_includes response.body, 'data-recipients-target="signatureQuota"'
    assert_includes response.body, 'data-recipients-target="meteraiQuota"'
    assert_includes response.body, 'data-recipients-target="signatureLine"'
    assert_includes response.body, 'data-recipients-target="meteraiLine"'
    assert_no_match(/rina\.halim@example\.test/, response.body)
    assert_no_match(/budi\.santoso@example\.test/, response.body)
  end

  test "row charge and quotas stay as derived markup, not stored inputs" do
    get sign_recipients_url(workspace_id: "ws-a")

    assert_response :success
    assert_includes response.body, 'data-field="subtotal"'
    assert_no_match(/name="total_charge"/, response.body)
    assert_no_match(/name="quota_remaining"/, response.body)
  end
end
