$(function() {

  //$("#main_sku_field").attr("disabled", false);
  
  $("#main_sku_field").focus();
  
  $("#main_sku_field").keyup(function(e) {
    if (e.keyCode == 13) {
      add_item($("#main_sku_field").val(), '');
    }
  })
  
  setInterval(function() {
    if (
      !$('#cash_drop').is(":visible") && 
      !$('#complete_order').is(":visible") && 
      !$('#inplaceedit-div').is(":visible") && 
      !$('#search').is(":visible") &&
      !$('.void-order').is(":visible") &&
      !$('.ui-keyboard').is(":visible") && 
      !$('.salor-dialog').is(":visible")
     ) {
    $("#main_sku_field").focus();
    } 
  }, 2000);
  
}); // documentready

function focusInput(inp) {
  $('.salor-focused').removeClass('salor-focused');
  inp.addClass('salor-focused');
  inp.focus();
}