
#ifndef DTTSP_KEYER_H
#define DTTSP_KEYER_H

#define NO_TIME_LEFTS_SCHED	(-2)
#define NO_ELEMENT		(-1)
#define DIT			 (0)
#define DAH			 (1)
#define MODE_A			 (0)
#define MODE_B			 (1)
#define NO_PADDLE_SQUEEZE	 (0)
#define PADDLES_SQUEEZED	 (1)
#define PADDLES_RELEASED	 (2)
#define NO_DELAY		 (0)
#define CHAR_SPACING_DELAY	 (1)
#define WORD_SPACING_DELAY	 (2)

typedef unsigned char BOOLEAN;

typedef struct {
  // KeyerLogic state
  struct {
    BOOLEAN init;
    struct {
      BOOLEAN dit, dah;
    } prev;
  } flag;
  struct {
    BOOLEAN altrn, // insert alternate element
      psqam; // paddles squeezed after mid-element
    int curr, // -1 = nothing, 0 = dit, 1 = dah
      iamb, //  0 = none, 1 = squeezed, 2 = released
      last; // -1 = nothing, 0 = dit, 1 = dah
  } element;
  struct {
    double beep, dlay, elem, midl;
  } time_left;
  int dlay_type; // 0 = none, 1 = interchar, 2 = interword
  // klogic parameters
  double wpm;
  int iambicmode;
  BOOLEAN need_midelemodeB;
  BOOLEAN want_dit_mem;
  BOOLEAN want_dah_mem;
  BOOLEAN autocharspacing;
  BOOLEAN autowordspacing;
  int weight;
  // computed parameters
  double ditlen;
} keyer_t;
  
static void *dttsp_keyer_init(void *arg) {
  keyer_t *kp = (keyer_t *)arg;
  kp->flag.init = 0;
  return arg;
}

//
// given the keyer_t state/option structure pointer,
// the current states of the dit and dah paddles,
// and the length of the tick since the last call
// in some unspecified unit,
// return true or false depending on whether the keyer output
// should be on or off
//
// ditlen in minutes/dit = minutes/word * word/dit = 1/(wpm * 50) = 
// ditlen in seconds/dit = 60 * minutes/dit = 60/ (wpm * 50)
// ditlen in ms/dit = 1000 * seconds/dit = 1200 / wpm
//

BOOLEAN dttsp_keyer(keyer_t *kp, BOOLEAN dit, BOOLEAN dah, double ticklen) {

  double ditlen = 1200 / kp->wpm; /* milliseconds */
  int set_which_ele_time_left = NO_TIME_LEFTS_SCHED;

  /** Do we need to initialize the keyer? */
  if (!kp->flag.init) {
    kp->flag.prev.dit = dit;
    kp->flag.prev.dah = dah;
    kp->element.last = kp->element.curr = NO_ELEMENT;
    kp->element.iamb = NO_PADDLE_SQUEEZE;
    kp->element.psqam = 0;
    kp->element.altrn = 0;
    kp->time_left.midl = kp->time_left.beep = kp->time_left.elem = 0;
    kp->time_left.dlay = 0;
    kp->dlay_type = NO_DELAY;
    kp->flag.init = 1;
  }

  /** Decrement the time_lefts */
  kp->time_left.dlay -= kp->time_left.dlay > 0 ? ticklen : 0;
  if (kp->time_left.dlay <= 0) {
    /* If nothing is scheduled to play,
       and we just did a character space delay,
       and we're doing auto word spacing,
       then pause for a word space,
       otherwise resume the normal element time_left countdowns */
    if (kp->time_left.elem <= 0 &&
	kp->dlay_type == CHAR_SPACING_DELAY &&
	kp->autowordspacing) {
      kp->time_left.dlay = ditlen * 4;
      kp->dlay_type = WORD_SPACING_DELAY;
    } else {
      kp->dlay_type = NO_DELAY;
      kp->time_left.midl -= kp->time_left.midl > 0 ? ticklen : 0;
      kp->time_left.beep -= kp->time_left.beep > 0 ? ticklen : 0;
      kp->time_left.elem -= kp->time_left.elem > 0 ? ticklen : 0;
    }
  }

  /** Are both paddles squeezed? */
  if (dit && dah) {
    kp->element.iamb = PADDLES_SQUEEZED;
    /* Are the paddles squeezed past the middle of the element? */
    if (kp->time_left.midl <= 0)
      kp->element.psqam = 1;
  } else if (!dit && !dah && kp->element.iamb == PADDLES_SQUEEZED)
    /* Are both paddles released and we had gotten a squeeze in this element? */
    kp->element.iamb = PADDLES_RELEASED;

  /** Is the current element finished? */
  if (kp->time_left.elem <= 0 && kp->element.curr != NO_ELEMENT) {
    kp->element.last = kp->element.curr;

    /** Should we insert an alternate element? */
    if (((dit && dah) ||
	 (kp->element.altrn &&
	  kp->element.iamb != PADDLES_RELEASED) ||
	 (kp->element.iamb == PADDLES_RELEASED &&
	  kp->iambicmode == MODE_B &&
	  (!kp->need_midelemodeB || kp->element.psqam)))) {
      if (kp->element.last == DAH)
	set_which_ele_time_left = kp->element.curr = DIT;
      else
	set_which_ele_time_left = kp->element.curr = DAH;

    } else {
      /* No more element */
      kp->element.curr = NO_ELEMENT;
      /* Do we do automatic character spacing? */
      if (kp->autocharspacing && !dit && !dah) {
	kp->time_left.dlay = ditlen * 2;
	kp->dlay_type = CHAR_SPACING_DELAY;
      }
    }

    kp->element.altrn = 0;
    kp->element.iamb = NO_PADDLE_SQUEEZE;
    kp->element.psqam = 0;
  }

  /** Is an element not currently being played? */
  if (kp->element.curr == NO_ELEMENT) {
    if (dah)		/* Dah paddle down? */
      set_which_ele_time_left = kp->element.curr = DAH;
    else if (dit)	/* Dit paddle down? */
      set_which_ele_time_left = kp->element.curr = DIT;
  }

  /** Take the dah memory request into account */
  if (kp->element.curr == DIT &&
      !kp->flag.prev.dah &&
      dah &&
      kp->want_dah_mem)
    kp->element.altrn = 1;

  /** Take the dit memory request into account */
  if (kp->element.curr == DAH &&
      !kp->flag.prev.dit &&
      dit &&
      kp->want_dit_mem)
    kp->element.altrn = 1;

  /** If we had a dit or dah scheduled for after a delay,
     and both paddles are up before the end of the delay,
     and we have not requested dit or dah memory,
     forget it
     NB can't happen in full mode B */

  if (kp->time_left.dlay > 0 && !dit && !dah &&
      ((kp->element.curr == DIT && !kp->want_dit_mem) ||
       (kp->element.curr == DAH && !kp->want_dah_mem)))
    set_which_ele_time_left = kp->element.curr = NO_ELEMENT;

  /** Set element time_lefts, if needed */
  switch (set_which_ele_time_left) {
  case NO_ELEMENT:		/* Cancel any element */
    kp->time_left.beep = 0;
    kp->time_left.midl = 0;
    kp->time_left.elem = 0;
    break;

  case DIT:			/* Schedule a dit */
    kp->time_left.beep = (ditlen * (double) kp->weight) / 50;
    kp->time_left.midl = kp->time_left.beep / 2;
    kp->time_left.elem = ditlen * 2;
    break;

  case DAH:			/* Schedule a dah */
    kp->time_left.beep = (ditlen * (double) kp->weight) / 50 + ditlen * 2;
    kp->time_left.midl = kp->time_left.beep / 2;
    kp->time_left.elem = ditlen * 4;
    break;
  }

  kp->flag.prev.dit = dit;
  kp->flag.prev.dah = dah;

  return kp->time_left.beep > 0 && kp->time_left.dlay <= 0;
}

#endif
