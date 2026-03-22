import {
  validateBid,
  validatePass,
  checkBiddingComplete,
  checkMalzoom,
} from '../../src/game/bid-validator';

describe('BidValidator', () => {
  describe('validateBid', () => {
    test('accepts first bid of 5', () => {
      const result = validateBid(5, null, [], 'p1');
      expect(result.valid).toBe(true);
    });

    test('accepts bid higher than current', () => {
      const result = validateBid(7, 6, [], 'p1');
      expect(result.valid).toBe(true);
    });

    test('rejects bid equal to current', () => {
      const result = validateBid(6, 6, [], 'p1');
      expect(result.valid).toBe(false);
      expect(result.error).toBe('bid-not-higher');
    });

    test('rejects bid lower than current', () => {
      const result = validateBid(5, 6, [], 'p1');
      expect(result.valid).toBe(false);
      expect(result.error).toBe('bid-not-higher');
    });

    test('rejects bid from player who already passed', () => {
      const result = validateBid(7, 6, ['p1'], 'p1');
      expect(result.valid).toBe(false);
      expect(result.error).toBe('already-passed');
    });
  });

  describe('validatePass', () => {
    test('allows pass for non-passed player', () => {
      const result = validatePass(['p0', 'p2'], 'p1');
      expect(result.valid).toBe(true);
    });

    test('rejects pass from player who already passed', () => {
      const result = validatePass(['p1'], 'p1');
      expect(result.valid).toBe(false);
      expect(result.error).toBe('already-passed');
    });
  });

  describe('checkBiddingComplete', () => {
    test('bidding complete when 3 players passed', () => {
      const result = checkBiddingComplete(['p0', 'p2', 'p3'], 6, 'p1');
      expect(result.complete).toBe(true);
      expect(result.winner).toBe('p1');
      expect(result.bid).toBe(6);
    });

    test('bidding not complete with fewer than 3 passes', () => {
      const result = checkBiddingComplete(['p0', 'p2'], 6, 'p1');
      expect(result.complete).toBe(false);
      expect(result.winner).toBeUndefined();
    });
  });

  describe('checkMalzoom', () => {
    test('first all-pass triggers reshuffle', () => {
      expect(checkMalzoom(['p0', 'p1', 'p2', 'p3'], 0)).toBe('reshuffle');
    });

    test('second all-pass triggers forced bid', () => {
      expect(checkMalzoom(['p0', 'p1', 'p2', 'p3'], 1)).toBe('forcedBid');
    });

    test('not all passed returns none', () => {
      expect(checkMalzoom(['p0', 'p1', 'p2'], 0)).toBe('none');
    });
  });
});
