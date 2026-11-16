//
//  UndoSupport.swift
//  AmmoTrack
//
//  Created by  Riccardo on 11/16/26.
//
//  Annulla / Ripeti: la differenza fra due versioni del registro e i passi delle pile.
//  Solo Foundation, come il resto del Core.
//

import Foundation

/// Che cosa è cambiato nel registro fra due versioni. Applicata va da "prima" a "dopo";
/// `inverted` fa il percorso opposto.
nonisolated struct MovementDiff: Sendable {
    nonisolated struct Entry: Sendable {
        let index: Int              // posizione nel file (serve a rimettere la riga dov'era)
        let movement: Movement
    }
    nonisolated struct Change: Sendable {
        let old: Movement
        let new: Movement
    }

    /// Righe da togliere.
    var removed: [Entry] = []
    /// Righe da inserire.
    var added: [Entry] = []
    /// Righe da sostituire (old → new, stesso id).
    var changed: [Change] = []

    var isEmpty: Bool { removed.isEmpty && added.isEmpty && changed.isEmpty }

    var inverted: MovementDiff {
        MovementDiff(removed: added,
                     added: removed,
                     changed: changed.map { Change(old: $0.new, new: $0.old) })
    }

    /// Applica la differenza a una lista appena riletta dal file.
    func apply(to list: inout [Movement]) {
        let toRemove = Set(removed.map { $0.movement.id })
        if !toRemove.isEmpty { list.removeAll { toRemove.contains($0.id) } }
        for c in changed {
            if let i = list.firstIndex(where: { $0.id == c.old.id }) { list[i] = c.new }
        }
        for e in added.sorted(by: { $0.index < $1.index }) {
            if list.contains(where: { $0.id == e.movement.id }) { continue }
            list.insert(e.movement, at: min(e.index, list.count))
        }
    }
}

extension MovementDiff {
    init(from before: [Movement], to after: [Movement]) {
        var beforeIndex: [String: Int] = [:]
        for (i, m) in before.enumerated() where beforeIndex[m.id] == nil { beforeIndex[m.id] = i }

        var removed: [Entry] = []
        var added: [Entry] = []
        var changed: [Change] = []
        var afterIDs = Set<String>()

        for (i, m) in after.enumerated() {
            afterIDs.insert(m.id)
            if let b = beforeIndex[m.id] {
                if before[b] != m { changed.append(Change(old: before[b], new: m)) }
            } else {
                added.append(Entry(index: i, movement: m))
            }
        }
        for (i, m) in before.enumerated() where !afterIDs.contains(m.id) {
            removed.append(Entry(index: i, movement: m))
        }
        self.init(removed: removed, added: added, changed: changed)
    }
}

nonisolated enum UndoChange: Sendable {
    case movements(MovementDiff)
    case config(before: Config, after: Config)
}

nonisolated struct UndoStep: Sendable {
    let name: String            // "Sparo 50", "Modifica arma"...: compare nel menu
    let change: UndoChange
}
