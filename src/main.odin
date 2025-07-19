package puzzle

import "core:log"

Piece :: struct {
    sides: [4]int
}







































debug :: log.debug
debugf :: log.debugf
info :: log.info
infof :: log.infof

main :: proc() {
    context.logger = log.create_console_logger(opt = {.Level, .Short_File_Path, .Line})
    defer log.destroy_console_logger(context.logger)
    debug("start of the season baby!!!!!!")
}

