# Release notes style

- Audience: players first (Discord announcement, launcher news), then staff.
- One line per change, starting with what the player sees. Present tense. No PR numbers in the
  player blocks; they go in the technical changelog.
- Order inside a section: most noticed first.
- Removals and breaking changes always get a heads-up line: what happens to existing items,
  blocks, settings ("Your old X blocks drop as Y").
- Numbers when they matter ("downloads 40% smaller", "Crafter uses 20% less energy").
- No exploit details for security fixes.

```markdown
## Arffornia mod 1.5.0 · 2026-11-02

### English
**New**
- The Constructor: a tier 1 machine that turns ingots into parts.
**Improved**
- Recipe selection shows locked recipes greyed out with the stage that unlocks them.
**Fixed**
- The milestone HUD is no longer hidden behind the minimap.
**Heads-up**
- The Crafter is now one block tall. Existing Crafters keep their contents.

### Français (à relire)
**Nouveautés**
- Le Constructeur : une machine de palier 1 qui transforme les lingots en pièces.
**Améliorations**
- La sélection de recette affiche les recettes verrouillées en grisé, avec le palier qui les débloque.
**Corrections**
- Le HUD du jalon n'est plus caché derrière la minimap.
**À savoir**
- Le Crafter ne fait plus qu'un bloc de haut. Les Crafters existants gardent leur contenu.

### Technical changelog
- https://github.com/Arffornia/Arffornia_Mods/pull/52 - fix(api): add HTTP timeouts and a single re-auth on 401
```

French: no-break space before `:` `;` `?` `!`; sentence case; "vous"; Arffornia terms
(jalon = milestone, palier = stage, boutique = shop, Ascenseur spatial = Space Elevator).
