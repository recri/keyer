#ifndef MIDI_H
#define MIDI_H

#ifdef __cplusplus
extern "C"
{
#endif

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

#ifdef __cplusplus
}
#endif

#endif
