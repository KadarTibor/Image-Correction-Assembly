# Image-Correction-Assembly
Steps to run the program:
- open TASM and type: TASM SandPC.asm
- type: TLINK SandPC
- type: SandPC <picture-file-name>.bmp ex: SandPC example1.bmp

The project aims to remove salt and pepper noise from from images by applying a median filter.

The median filter works the following way:
- sort the neighbours of a pixel (considering the 8 neighbour scheme) by value and pick the value in the midle of the list as the new value of the pixel.
- apply this algorithm only for pixels which are either black or white.
