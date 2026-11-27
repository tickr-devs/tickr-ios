import Foundation
import SwiftUI
import Testing
@testable import TickrDesign
import TickrKit

/// The one map of each operator-facing meaning (Meanings.swift): a stop's state, a headline's
/// severity, a verdict, an exit.
@Suite struct MeaningsTests {
  static let states: [StopState] = [.verified, .pending, .missing, .unknown]

  @Test("Only a verified stop protects; pending amber, missing and unknown red (mockup v100)")
  func stopTones() {
    #expect(Self.states.map(\.isProtected) == [true, false, false, false])
    #expect(Self.states.map(\.tone) == [.profit, .warning, .loss, .loss])
  }

  @Test("One symbol per stop state, none shared with the stop's level")
  func stopSymbols() {
    #expect(Self.states.map(\.symbol) == ["checkmark.shield", "hourglass", "xmark.shield", "exclamationmark.shield"])
    #expect(Set(Self.states.map(\.symbol)).count == Self.states.count)
    #expect(!Self.states.map(\.symbol).contains(StopState.levelSymbol))
  }

  @Test("A set of stops takes the worst one's tone and symbol, never a fixed check")
  func stopSets() {
    #expect(StopState.combinedTone([]) == .neutral)
    #expect(StopState.combinedTone([.verified, .verified]) == .profit)
    #expect(StopState.combinedTone([.verified, .pending]) == .warning)
    #expect(StopState.combinedTone([.pending, .missing, .verified]) == .loss)
    #expect(StopState.combinedSymbol([.verified, .pending]) == StopState.pendingSymbol)
    #expect(StopState.combinedSymbol([.unknown, .missing]) == StopState.missingSymbol)
    #expect(StopState.combinedSymbol([.verified]) == StopState.verifiedSymbol)
    #expect(StopState.combinedSymbol([]) == StopState.levelSymbol)
    #expect(StopState.allProtected([]))
  }

  @Test("The broker-stop stage: green with no position on every screen, unless a day's trade lost its stop")
  func stopStage() {
    #expect(StopState.stageTone(open: []) == .profit)
    #expect(StopState.stageTone(open: [], day: [.verified, .pending]) == .profit)
    #expect(StopState.stageTone(open: [], day: [.verified, .neverVerified]) == .loss)
    #expect(StopState.stageTone(open: [.verified], day: [.verified]) == .profit)
    #expect(StopState.stageTone(open: [.verified], day: [.pending]) == .warning)
    #expect(StopState.stageTone(open: [.pending]) == .warning)
    #expect(StopState.stageTone(open: [.verified, .missing]) == .loss)
  }

  @Test("The glyph's label names the symbol and the state")
  func stopLabel() {
    #expect(StopGlyph.label(.pending, symbol: "ABCD") == "ABCD · " + Board.stopStateTitle(.pending))
  }

  @Test("Headline tones (mockup v108): calm teal, attention amber, alarm red")
  func headlineTones() {
    #expect([Severity.ok, .attention, .alarm].map(\.tone) == [.accent, .warning, .loss])
    #expect(Headline(text: "", severity: .ok).tone == .accent)
    #expect(Headline(text: "", severity: .attention).tone == .warning)
    #expect(Headline(text: "", severity: .alarm).tone == .loss)
  }

  @Test("The gate badge (mockup v109): open green, paused amber, closed grey with a lock")
  func gateTones() {
    #expect([EntryGate.open, .paused, .closed].map(\.tone) == [.profit, .warning, .neutral])
    #expect([EntryGate.open, .paused, .closed].map(\.symbol) == [nil, nil, Symbols.gateClosed])
  }

  @Test("Verdicts: ENTER and HOLD accent, WATCH info, IGNORE pink, EXIT warning, all text roles")
  func verdicts() {
    let verdicts: [Verdict] = [.enter, .hold, .watch, .ignore, .exit]
    #expect(verdicts.map(\.textSwatch) == [.accentText, .accentText, .infoText, .seriesATRText, .warningText])
    #expect(verdicts.map(\.color)
      == [Palette.accentText, Palette.accentText, Palette.infoText, Palette.seriesATRText, Palette.warningText])
  }

  @Test("A tone's text colour and its swatch name the same role")
  func toneTexts() {
    let tones: [Tone] = [.neutral, .accent, .profit, .loss, .warning, .info, .highlight, .series]
    #expect(tones.map(\.text) == [Palette.textTertiary, Palette.accentText, Palette.profitText, Palette.lossText,
      Palette.warningText, Palette.infoText, Palette.highlightText, Palette.seriesATRText])
    #expect(tones.map(\.textSwatch) == [.textTertiary, .accentText, .profitText, .lossText, .warningText, .infoText,
      .highlightText, .seriesATRText])
    #expect(Palette.result(0) == Palette.textTertiary)
    #expect(Palette.result(d("-1")) == Palette.seriesATRText)
  }

  @Test("Trade tags by reason (v99): strategy exit and open teal, stopped out pink, other closes grey")
  func exits() {
    #expect(Tone.exit("strategy-exit") == .accent)
    #expect(Tone.exit("stopped-out") == .series)
    #expect(Tone.exit("closed") == .neutral)
    #expect(Tone.exit("session-flatten") == .neutral)
    #expect(Tone.exit("stream-lost") == .neutral)
    #expect(Tone.exit("stop-rejected") == .loss)
    #expect(Tone.exit("unprotected-too-long") == .loss)
    #expect(Tone.exit("a-reason-not-known-yet") == .neutral)
    // A replay's words (what-ifs): the same tags.
    #expect(Tone.exit("stop") == .series)
    #expect(Tone.exit("strategy_exit") == .accent)
    #expect(Tone.exit("flatten") == .neutral)
    #expect(Tone.openPosition == .accent)
  }

  @Test("Every bot tone maps to one design tone")
  func eventTones() {
    let tones: [Board.Event.Tone] = [.teal, .green, .blue, .amber, .violet, .red, .muted]
    #expect(tones.map { Tone($0) } == [.accent, .profit, .info, .warning, .highlight, .loss, .neutral])
  }

  @Test("A loss or a reservation is coloured only while it shows more than $0.00")
  func amountsNeutralAtZero() {
    #expect(Tone.loss(0) == .neutral)
    #expect(Tone.loss(d("0.004")) == .neutral)
    #expect(Tone.loss(d("1.60")) == .series)
    #expect(Tone.amount(0, .warning) == .neutral)
    #expect(Tone.amount(d("0.004"), .warning) == .neutral)
    #expect(Tone.amount(d("50"), .warning) == .warning)
  }

  @Test("A money result: profit above zero, loss below, neutral at zero (never green)")
  func results() {
    #expect(Tone.result(d("0.01")) == .profit)
    #expect(Tone.result(d("-0.01")) == .series)
    #expect(Tone.result(0) == .neutral)
    // Coloured as shown: "−0.004" reads "$0.00" and is neutral; "−0.005" reads "−$0.01", a loss.
    #expect(Money.signedUSD(d("-0.004")) == "$0.00")
    #expect(Tone.result(d("-0.004")) == .neutral)
    #expect(Tone.result(d("0.004")) == .neutral)
    #expect(Money.signedUSD(d("-0.005")) == "\u{2212}$0.01")
    #expect(Tone.result(d("-0.005")) == .series)
    // R results shown to one decimal: −0.04 R reads "0.0 R".
    #expect(Tone.result(d("-0.04"), fractionDigits: 1) == .neutral)
  }
}

/// The live flow's stage colours (StageColour.swift), compared by their light and dark values:
/// no SwiftUI colour is resolved off the main thread (a `Color.resolve(in:)` here hung the whole
/// test run on CI, #853 and #855, 2026-11-27).
@Suite struct StageColourTests {
  @Test("Nine stages, nine different hues, in the approved order")
  func distinct() {
    let stages = PipelineStage.allCases
    #expect(stages.count == 9)
    for value in [\Swatch.light, \Swatch.dark] {
      #expect(Set(stages.map { $0.fillSwatch[keyPath: value] }).count == stages.count)
      #expect(Set(stages.map { $0.textSwatch[keyPath: value] }).count == stages.count)
    }
  }

  @Test("Priced cyan, Bought orange and Checked lime are the new palette colours")
  func newColours() {
    #expect(PipelineStage.quote.fillSwatch == .cyan)
    #expect(PipelineStage.order.fillSwatch == .orange)
    #expect(PipelineStage.reconcile.fillSwatch == .lime)
    #expect(PipelineStage.stop.fillSwatch == .profit)
  }
}
