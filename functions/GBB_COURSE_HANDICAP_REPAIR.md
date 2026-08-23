# GBB Course Handicap Repair

This repair is dry-run only unless `--write` is supplied. It refuses any round
whose share code is not exactly `GBB`, any count other than 33 participants and
297 score documents, stale source revisions, changed participant allowances or
tees, incomplete manifest rows, and unsupported multi-owner scoring-unit
allowances.

## Commissioner inputs

Copy `gbb-course-handicap-repair.manifest.example.json` to an untracked working
file and provide:

- the production series, series-round and linked-round IDs;
- all 33 Excel Course HCP values and gross totals;
- the participant/member IDs, current allowance, current tee and intended tee;
- the front-nine course/tee context and Karis's `red_female` participant ID;
- official front-nine rating and slope for every used tee, if available;
- the current round, series-round and canonical-generation revisions.

Set `completeAuthoritativeTeeMetadata` to `true` only when every used tee has an
official front-nine rating and slope. Otherwise the repair keeps GBB handicap
history visible while excluding it from future handicap-index math.

For a hole-dependent format, verify and enter the physical hole scores first,
then set `holeScoresVerifiedFromPhysicalCards` to `true`.

## Run

Authenticate the Admin SDK before running the standalone script:

```sh
gcloud auth application-default login
```

```sh
cd functions
npm run repair:gbb-course-handicaps -- \
  --project hackers-compete \
  --manifest /absolute/path/to/gbb-repair.json
```

Review every player, Karis's tee, the score counts, canonical sample count and
handicap eligibility. Apply only after that review:

```sh
npm run repair:gbb-course-handicaps -- \
  --project hackers-compete \
  --manifest /absolute/path/to/gbb-repair.json \
  --write
```

After a successful write, open GE League in the upgraded commissioner app. The
pending processing state triggers reconciliation. Verify the Week 11 matchups,
awards and rebuilt leaderboard against Excel and the physical cards.

Running the same manifest again after a successful repair is a no-op.
