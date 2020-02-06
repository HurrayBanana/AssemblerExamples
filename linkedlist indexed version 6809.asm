;***************************************************************************
; Linked list example in 6809, using indexed addressing
; copyright Hurray Banana 2018
;***************************************************************************
;***************************************************************************
; Variable / RAM SECTION
;***************************************************************************
; insert your variables (RAM usage) in the BSS section
; user RAM starts at $c880 
                    BSS      
                    ORG      $c880                        ; start of our ram space 
;***************************************************************************
; link node structure is fixed size
; 1st byte data item
; next byte is index for link to next data item in list or ff for null
; single byte locks list size to 255 entries, could easily use a 16 bit addr
; for larger lists
;***************************************************************************
DATA                equ      0                            ;offset for simpl 
LINK                equ      1                            ;offset for link 
NODE_SIZE           equ      2 
MAX_ENTRIES         equ      5                            ;size of linked list 
NULL                equ      $ff                          ;null pointer 
head                ds       1                            ;points to index of linked list 
free                ds       1                            ;points to index of free lisst 
linked_list:        ds       NODE_SIZE * MAX_ENTRIES      ;declare space for linked list 
;***************************************************************************
; CODE SECTION
;***************************************************************************
                    CODE     
                    ORG      0 							  ;start assembly at memory address 0
                    jsr      initialise_lists 
                    
					ldb      #32 						  ;add some items to the list
                    jsr      add_list_item 
                    ldb      #48 
                    jsr      add_list_item 
                    ldb      #16 
                    jsr      add_list_item 
                    
                                                           
                    jsr      process_list 
main: 
                    BRA      main                         ; and repeat forever 

;***************************************************************************
; Sets up the free list and nulls head pointer
; use $ff (-1) for null pointer
;***************************************************************************
initialise_lists: 
                    lda      #NULL                        ;immediate addressing 
                    sta      head                         ;direct addressing 
                    ldb      #MAX_ENTRIES-1               ;load up number of entries in linked list 
                    clra     
                    sta      free                         ;set free list ot point at first indexx 
                    ldx      #linked_list + LINK          ;get address of linked list in X register 
set_list_entry: 
                    inca                                  ;set b to point to next index and store in current node 
                    sta      ,x++                         ;post increment index register (we want to move 2 bytes) 
                    decb                                  ;decrease entries to configure 
                    bne      set_list_entry               ;loop back if more to do 
                    lda      #NULL                        ;set null pointer for final node 
                    sta      ,x 
                    rts      

;***************************************************************************
; process the entire linked list
;***************************************************************************
process_list: 
                    ldy      #linked_list                 ;load table start in index register 
                    lda      head 
process_check_null: 
                    cmpa     #NULL 
                    bne      process_continue 
                    rts                                   ;empty 

process_continue: 
                    lsla                                  ;mult by two to get an offset in table 
                    tfr      y,x                          ;get base of linked list 
                    leax     a,x                          ;get address of free pointer entry in x 
                    pshs     x                            ;save x register 
                    jsr      process_data_item 
                    puls     x                            ;get x back 
                    lda      LINK,x 
                    bra      process_check_null 

;***************************************************************************
; code here to process the list item
; currently unpopulated
;***************************************************************************
process_data_item: 
                    rts      

;***************************************************************************
; new data held in b register, to be inserted into free list
; assuming no order so we insert at the head
; basic process is: 
; if (free != null)
;    newnode = free
;    linkedlist[newnode].data = b
;    free = linkedList[newnode].link
;    linkedlist[newnode].link = head
;    head = newnode;
;    return newnode
; else
;     return null
; returns with either index of new entry or NULL ref in a register
;***************************************************************************
add_list_item: 
                    lda      free                         ;get index of next place in free list available 
                    cmpa     #NULL 
                    bne      add_list_item_space 
                    rts                                   ;no space return null 

add_list_item_space: 
                    ldx      #linked_list                 ;load table start in index register 
                    lsla                                  ;mult by two to get an offset in table 
                    leax     a,x                          ;get address of free pointer entry in x 
                    stb      DATA,x                       ;store our new data item in this free node 
                    tfr      a,b                          ;copy the index of these free node to b ready for head update 
                    lda      LINK,x                       ;get address of next free entry 
                    sta      free                         ;and update free list to point to it 
                    lda      head                         ;get index pointer to head of linked list 
                    sta      LINK,x                       ; and store as the link in our new data node 
                    lsrb                                  ;divide by 2 to get index value back 
                    stb      head                         ;store index of the new node in head 
                    tfr      b,a                          ;return with index of new node 
                    rts      

;***************************************************************************
; add node to free list
; x contains addr of node to add to free list
; a contains the index of the node
; always add at head of free list as order is irrelevant
;***************************************************************************
free_add_node: 
                    ldb      free                         ;get index of free list 
                    sta      free                         ;store index of deleted node in free pointer 
                    stb      LINK,x                       ;store link to old head of free list in the deleted node 
                    rts      

;***************************************************************************
; removes the node containing data item held in b if possible
; returns null if item does not exist or index in a
;***************************************************************************
remove_list_item: 
                    ldx      #linked_list                 ;load table start in index register 
                    lda      head                         ;get head pointer 
                    cmpa     #NULL                        ;check for empty list 
                    bne      remove_check_head 
                    rts                                   ;no items in the list 

remove_check_head: 
                    lsla                                  ;mult by 2 
                    leax     a,x                          ;get addr of node 
                    cmpb     DATA,x                       ;is this the one we want 
                    beq      remove_head 
                    lda      LINK,x                       ;get next item 
remove_check_link: 
                    cmpa     #NULL 
                    bne      remove_continue 
                    rts                                   ;does not exist in list 

remove_continue: 
                    tfr      x,y                          ;y register hold addr of current node 
                    lsla     
                    ldx      #linked_list                 ;load table start in index register 
                    leax     a,x                          ;move to next node 
                    cmpb     DATA,x 
                    beq      remove_this 
                    lda      LINK,x                       ; get next 
                    bra      remove_check_link 

remove_this: 
                    ldb      LINK,x                       ;get node to be deleted's link 
                    stb      LINK,Y                       ; set previous nodes link to point to deleted nodes link 
                    lsra                                  ;divide by 2 to get the index of deleted node for adding to free list 
                    ldb      free                         ;get index of free list 
                    sta      free                         ;store index of deleted node in free pointer 
                    stb      LINK,x                       ;store link to old head of free list in the deleted node 
                    rts      

remove_head: 
                    lsra                                  ;divide by 2 to get index of node being deleted 
                    ldb      free                         ;get index of free list 
                    sta      free                         ;store index of deleted node in free pointer 
                    lda      LINK,x                       ;set head pointer to link of this node 
                    sta      head 
                    stb      LINK,x                       ;store link to old head of free list in the deleted node 
                    rts      

;***************************************************************************
; find node, b contains data looking for
; returns index of node in a register or null
; serial search
;***************************************************************************
find_list_item: 
                    ldx      #linked_list                 ;load table start in index register 
                    lda      head                         ;get head pointer 
                    cmpa     #NULL                        ;check for empty list 
                    bne      find_continue 
                    rts                                   ;no items in the list 

find_continue: 
                    lsla                                  ;mult by 2 
                    leax     a,x                          ;get addr of node 
                    cmpb     DATA,x                       ;is this the one we want 
                    beq      find_found 
                    lda      LINK,x                       ;get next item 
                    cmpa     #NULL 
                    bne      find_continue 
                    rts                                   ;not found 

find_found: 
                    lsra                                  ;divide by 2 to get index of node 
                    rts      

;***************************************************************************
