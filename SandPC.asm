;This program will process an image pixel by pixel correcting the noise

;the noise consists of either black or white pixels scattered around the image introducing 
;the so called Salt and Pepper noise

;each pixel is corrected using the median filter algorithm

;the median filter algorithm consists of sorting the 8 neighbours of a pixel and picking the middle value 
;-> replace foulty pixel with the value of the 5th pixel in the sorted array

Data segment para public 'data'

inputFile   DB 12 dup(?)
fileextension   DB ".bmp"
errormsg   DB  13,10,"Could not open file!",'$'
tests DB 10,13,"Test",'$'
GW DB 13,10,"The file was written",'$'
NGW DB 13,10,"The file was not written",'$'
confirmOpen  DB  13,10,"The file was opened successfully!",'$'
confirmHeader  DB 13,10,"The header was read successfully!",'$'
badHeader   DB 13,10,"The header was not read successfully!",'$'
fpMoved   DB 13,10,"The file pointer was moved successfully!",'$'
fpnotMoved   DB 13,10,"The file pointer was not moved succesfully!",'$'
dataGR    DB 13,10,"The Image Data was read succesfully!",'$'
dataNGR   DB 13,10,"The image data was not read succesfully!",'$'
welcomeMsg   DB  "Welcome to the Salt and Pepper noise correction program!",13,10,13,10,"Please introduce the name of the bitmap file:",13,10,'$'
inputFileHandle   DW ?
invalidInputmsg  DB 13,10,"Invalid input!",13,10,'$'
fileHeader   DB 54 dup(?)
imageWidth   DB ?
imageHeight    DB ?
imageDataOffset DW ?
padding DB ?
GC DB 10,13,"The file was closed successfully!",'$'
NGC DB 10,13,"The file was not closed successfully!",'$'
imageData    DB  256*200 dup(?) ;chose an arbitrary big enaugh size for the image data

Data ends

OutData segment para public 'data'


row1 DW ?
row2 DW ?
row3 DW ?

neighbours DB 8 dup(?)
sneighbours DB 8 dup(?)
correctedData DB 256*200 dup(?)


OutData ends

;the code segment 

Code segment para public 'code'

ReadFileName proc Far
assume cs:code,ds:Data,es:OutData

;display the welcome string
mov ah,09h;function that displays a string
lea dx,welcomeMsg;move the strings location in dx
int 21h;call intrerupt 21h


;read the file name
;restrict file name length to 8.3 format
;prepare the registers for reading
mov ah,01h; function to read single characters echoed to the screen
mov cx,08; restrict the length of the name to 8
lea bx,inputFile;get the address of the input file

readChar:
				int 21h;call the intrerupt that will read a characters
				cmp al,13; the pressed button was enter
				je finishedReading;
				;if it is not enter then we have to put the name into memory
				mov [bx],al;put the character into location in memory
				inc  bx; increment memory pointer
				loop readChar;

invalidName:
                   mov ah,09h;function that displays a string
				   lea dx,invalidInputmsg;move the strings location in dx
				   int 21h;call intrerupt 21h
				   xor ax,ax; destroy the register to prepare it for reading characters again
				   mov ah,01h;reput the function to read character
				   lea bx,inputfile;reput the adress in order to not write continuosly
				   jmp readChar;
				
finishedReading: 
				cmp cx,8; 
				je invalidName;name must not be an empty string
				;add extension
				mov cx,4;
				lea si,fileextension;move the file extension into si
			copyextension:	
			                       mov dl,[si];move the character into dl
								   mov [bx],dl;place it in the original string
								   inc si
								   inc bx
			loop copyextension; loop

ret
ReadFileName endp


;this procedure will open the file for read-write

OpenFile proc far
assume cs:code,ds:Data,es:OutData
;prepare to open the file

xor ax,ax   ;empty the register
mov ah,3dh ;put the code to open file
mov al,2; open the file in read-write mode
lea dx, inputFile  ;put the name of the file into the dx register
int 21h ; call intrerupt that will call function 3dh-> open the file

		;check whether the file was opened or nah
		jnc Opened;jumps to the place where it displays an error messege
		
		;if it reaches this point it means that the file was not opened and the program must end
		lea dx,errormsg ;move the address of the error messege string 
		mov ah,09h ;move the code to display a string
		int 21h ;call the intrerupt
	  
		mov ah,4ch
		int 21h;end the program


Opened: 
        ;if it reaches to this point it means that the file was indeed opened

		lea bx,inputFileHandle ;get the address of the handle variable
		mov [bx],al  ;mov the handle to memory
		lea dx,confirmOpen  ; move the confirmation string into dx 
		mov ah,09h ; place the function to be called in ah
		int 21h  ;call intrerupt 21h
ret		

OpenFile endp


;this procedure will read the first 54 bytes from the file which contain the header
;and put valuable information into variables

ProcessHeader proc far
assume cs:code,ds:Data,es:OutData


mov ah,3fh;function that reads data from the file
	mov bx,inputFileHandle;put the handle of the file into bx
	mov cx,54; the size of the header of a bitmap file
	lea dx,fileHeader; mov the buffer into dx
	int 21h;call the intrerupt
	jnc headerRead;
	
    ;display error messege for header reading
	mov ah,09h;
	lea dx,badHeader;messege if header was not read for some reason
    int 21h;call the intrerupt
    jmp over  ;jump to the end of the program
	
	
headerRead:
     mov ah,09h
     lea dx,confirmHeader;the header was read succesfully
     int 21h;call the intrerupt	 
	 
;supply information about the file from the header	 
	lea bx, fileheader
	mov dl, [bx+18] ;offset to the width
	mov imageWidth,dl;
	mov dl,[bx+22]  ;offset to the height
	mov imageHeight,dl
	mov dx,[bx+10] ;offset to the image data
	mov imageDataOffset,dx
ret
ProcessHeader endp


;this procedure will calculate the amount of data to be read and from a certain offset obtained from the header;
;it moves he file pointer to the speific position where file image data starts

ReadFile proc far
assume cs:code,ds:Data,es:OutData

 ;calculate the padding
	  xor ax,ax
	  mov al,imagewidth
	  mov bl,4
	  div bl
	  mov padding,ah;


;now read everything into the segment from the file
;the file pointer must be moved to the imageDataOffset
;we use function 42h "LSEEK" and intrerupt 21h
    mov ah,42h
    mov al,0;start from the origin
	mov bx,inputFileHandle; move file handle to bx
	mov cx,0; high part of the address of the offset, in our case its 0 becouse we know that imageDataOffset is DW
	mov dx,imageDataOffset
	int 21h
	jnc pointerMoved;
	;if it reaches this code it means something went wrong and mission must abort
	mov ah,09h
    lea dx,fpnotMoved
    int 21h
	jmp over
	
pointerMoved: ;this means the file pointer is in place and we can read the image data into memory
     
	 ;display confirmation messege
	 xor ax,ax
	 mov ah,09h
	 lea dx,fpMoved
	 int 21h
	 
	 ;reading the data from the file
	 xor ax,ax
	 mov al,imageWidth;
	 add al,padding
	 mul imageHeight
	 mov cx,ax;move the number of bytes to read into cx
	 xor ax,ax;prepare to put the function name in it
     xor dx,dx;make it empty and put the buffer in it
     mov ah,3fh
     mov bx,inputFileHandle
	 lea dx,imageData
	 int 21h 
	 jnc dataRead
	  
	 ;if it reaches here it means that it is an error occurred and data could not been read
	 xor ax,ax
	 mov ah,09h
	 lea dx,dataNGR
	 int 21h
	 jmp over;
	 
dataRead: ;this means that the data has been succcesfully read	 
     ;display confirmation messege
	 xor ax,ax
	 mov ah,09h
	 lea dx,dataGR
	 int 21h

	 ret
	 
ReadFile endp



;this is the main procedure which will call all the rest, also will perform the actual algorithm

Main proc 
assume cs:code,ds:Data,es:OutData

push ds
xor ax,ax
push ax
mov ax,Data
mov ds,ax
mov ax,OutData
mov es,ax

call ReadFileName

call OpenFile

call ProcessHeader	  
	  	
call ReadFile	
	
	 
	 
	 ;here it will compute the algortihm on the imageData
	 ;the 3 rows will be filled with data from the imageData
	 ;first row has to remain the same
	 
	 lea si,imageData
	 lea di,correctedData
	 mov cl,imagewidth
	 rep movsb
	 
	 ;set up registers for the loops
	 lea dx,imageData;dx points to the memory location of the imageData
	 xor cx,cx
	 xor ax,ax
	 mov cl,imageHeight;nr of rows 
	 dec cl;no need for the first row
	 mov al,imagewidth
	 mov bl,padding
	 add al,bl
	 mov si,ax;counter for the correctedData
     

   ;initialize the rows
    xor ax,ax         
	xor bx,bx
	mov row1,dx
	
	mov al,imagewidth
	mov bl,padding
	
    add dx,ax
	add dx,bx
	
	mov row2,dx
	add dx,ax
	add dx,bx
	
    mov row3,dx   
	 
passRow:
    
	
	push cx;
	mov cl,imageWidth;nr of columns
	
	
	passColumn:
			               
	push si
	mov si, [row2] 
	mov ah,ds:[si]
	cmp cl, imageWidth ;compares the color with black or white
	je end1
	cmp cl,1
	je end1
	cmp ah,0
	je constructor
	cmp ah,255
	jne end11
	je constructor
						   
	end1:
		pop si
		mov bx, [row2] 
	    mov ah,ds:[bx]
		mov correctedData[si],ah
		jmp secondloopending
								
	end11:
								
		pop si
		mov correctedData[si],ah
	    jmp secondloopending;
						   
	constructor:		
						
		;construct the neighbours vector
		mov si,[row1]
		mov al,ds:[si]
		mov neighbours[0],al; i+1,j-1
						   
		mov al,ds:[si+1]
		mov neighbours[1],al; i+1,j
						   
		mov al,ds:[si+2]
		mov neighbours[2],al; i+1,j+1
						   
		mov si,[row2]
		mov al,ds:[si]
		mov neighbours[3],al; i,j-1
						
		mov al,ds:[si+1]
		mov neighbours[4],al; ij
				   
		mov al,ds:[si+2]	
		mov neighbours[5],al; i,j+1
					
		mov si,[row3]
		mov al,ds:[si]
		mov neighbours[6],al; i-1,j-1
						   
		mov al,ds:[si+1]
		mov neighbours[7],al; i-1,j
					   
		mov al,ds:[si+2]
		mov neighbours[8],al; i-1,j+1
						   
		;sorting them
		push cx
						
		mov cx,8
		mov si,0;counter for first loop to cycle through the vector
		s1:
			push cx
			mov cx,8 
			sub cx,si
			mov ah,neighbours[si]
			mov bx,si;counter for second loop to cycle through the vector
			inc bx
		s2:
			mov al,neighbours[bx]
			cmp ah,al
			jle smaller 
			;interchange them
			xchg ah,neighbours[bx]
		    xchg al,neighbours[si]
							
			smaller:
			inc bx
			loop s2
						 
			pop cx;get the previous counter back
			inc si;move 1 step up the array
			loop s1
								
		;sorting ended	
		pop cx;get the counter from before the sorting
		pop si
		;put the corrected pixel into memory
		mov  al,neighbours[4]
		mov  correctedData[si],al
				
	secondloopending:
		inc si;increment the pointer  in the imageData
		inc row1
		inc row2
		inc row3
								
		dec cx
		cmp cx,0
		je end2
		jmp passColumn
			
		end2:
		        xor bx,bx
		        mov bl,padding
				add si,bx;leave bytes for padding
			   
			    pop cx
				add row1,bx
				add row2,bx
				add row3,bx
				
				
				dec cx
				cmp cx,1
				je moveOn
				jmp passRow
						   
moveOn:
	
   
   ;move the pointer in the file
    mov ah,42h
    mov al,0;start from the origin
	mov bx,inputFileHandle; move file handle to bx
	mov cx,0; high part of the address of the offset, in our case its 0 becouse we know that imageDataOffset is DW
	mov dx,imageDataOffset
	int 21h
	jnc pointerMoved1;
	;if it reaches this code it means something went wrong and mission must abort
	mov ah,09h
    lea dx,fpnotMoved
    int 21h
	jmp over
	
pointerMoved1: ;this means the file pointer is in place and we can read the image data into memory
     
	 ;display confirmation messege
	 xor ax,ax
	 mov ah,09h
	 lea dx,fpMoved
	 int 21h

assume ds:Outdata, es:data
mov ax,outdata
mov ds,ax

mov ax,data
mov es,ax
xor ax,ax	 
mov bx,inputFileHandle
mov al,imageheight
mul imagewidth
mov cx,ax
xor ax,ax
mov ah,40h
lea dx,correctedData
int 21h

assume ds:Data,es:OutData
mov ax,outdata
mov es,ax

mov ax,data
mov ds,ax

jnc goodWrite

;display confirmation messege
	 xor ax,ax
	 mov ah,09h
	 lea dx,NGW
	 int 21h
goodWrite:
 ;display confirmation messege
	 xor ax,ax
	 mov ah,09h
	 lea dx,GW
	 int 21h


;the pixel values are computed
;put them back into the file
;swap segments es and ds becouse the corrected data must be in ds


;close the file
mov ah,3eh
mov bx, inputFileHandle
int 21h
jnc goodclose
mov ah,09h
lea dx,NGC
int 21h

goodclose:
     mov ah,09h
	 lea dx, GC
	 int 21h


over:
mov ah,4ch;function that ends the program
int 21h; call intrerupt 21h
ret

Main endp
Code ends
end main