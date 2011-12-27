#ifndef KEYER_MIDI_H
#define KEYER_MIDI_H
/*
** MIDI commands semi-implemented
*/
#define NOTE_OFF	0x80
#define NOTE_ON		0x90
#define NOTE_TOUCH	0xA0
#define CHAN_CONTROL	0xB0
#define SYSEX		0xF0
#define SYSEX_VENDOR	0x7D
#define SYSEX_END	0xF7

extern int midi_readable();
extern unsigned midi_duration();
extern unsigned short midi_count();
extern void midi_read_bytes(short count, unsigned char *bytes);
extern void midi_read_next();
extern void midi_write(unsigned duration, short count, unsigned char *bytes);
extern void midi_sysex_write(char *p);

#endif
