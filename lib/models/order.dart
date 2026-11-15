class OrderStatus {
  static const pending = 'pending';
  static const paid = 'paid';
  static const processing = 'processing';
  static const shipped = 'shipped';
  static const delivered = 'delivered';
  static const cancelled = 'cancelled';

  static const all = [pending, paid, processing, shipped, delivered, cancelled];
}

class PaymentMethod {
  static const all = ['bakong', 'paypal', 'cod'];
}
