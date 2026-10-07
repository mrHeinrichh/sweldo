/// Runs futures in parallel and rethrows the first failure as-is (rather than
/// wrapped in a `ParallelWaitError`), so error messages stay specific.
Future<(A, B)> both<A, B>(Future<A> a, Future<B> b) async {
  final results = await Future.wait<Object?>([a, b], eagerError: true);
  return (results[0] as A, results[1] as B);
}

Future<(A, B, C)> all3<A, B, C>(Future<A> a, Future<B> b, Future<C> c) async {
  final results = await Future.wait<Object?>([a, b, c], eagerError: true);
  return (results[0] as A, results[1] as B, results[2] as C);
}
