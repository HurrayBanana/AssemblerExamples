;***************************************************************************
; Linked list example in 6809, using 16 bit addressing
; copyright Hurray Banana 2018
;***************************************************************************

;***************************************************************************
; link node structure is fixed size
; 1st byte data item
; next 2 bytes are address of next node
;***************************************************************************
DATA                equ      0                            ;offset for simpl 
LINK                equ      1                            ;offset for link 
NODE_SIZE           equ      3 
MAX_ENTRIES         equ      5                            ;size of linked list 
NULL                equ      $ffff                        ;null pointer 
;***************************************************************************
; Variable / RAM SECTION
;***************************************************************************
; insert your variables (RAM usage) in the BSS section
; user RAM starts at $c880 
                    BSS      
                    ORG      $c880                        ; start of our ram space
; Ram memory allocations ds directive lables the number of bytes specified
head:               ds       2                            ;points to addr of first node 
free:               ds       2                            ;points to addr of first node 
linked_list:        ds       NODE_SIZE * MAX_ENTRIES      ;declare space for linked list 
end_of_list:        ds       2 
END_LINK_LIST:      equ      linked_list + NODE_SIZE * MAX_ENTRIES ; address following list 
;***************************************************************************
; CODE SECTION
;***************************************************************************
                    CODE     
                    ORG      0 

                    jsr      initialise_lists 
                    ldb      #32 
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
; use $ffff (-1) for null pointer
;***************************************************************************
initialise_lists: 
                    ldd      #NULL                        ;immediate addressing 
                    std      head                         ;direct addressing 
                    ldy      #END_LINK_LIST               ;load up addr after linked list 
                    ldd      #linked_list 
                    std      free                         ;set free list to start of table 
initialise_loop: 
                    tfr      d,x 
                    addd     #3 
                    cmpd     end_of_list 
                    beq      initialise_complete 
                    std      LINK,x                       ;set free list ot point at first indexx 
                    bra      initialise_loop 
initialise_complete:
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
                    ldb      LINK,x                       ;t ;get node to be deleted's link 
                    stb      LINK,Y                       ;t ; set previous nodes link to point to deleted nodes link 
                    lsra                                  ;t ;divide by 2 to get the index of deleted node for adding to free list 
                    ldb      free                         ;t ;get index of free list 
                    sta      free                         ;t ;store index of deleted node in free pointer 
                    stb      LINK,x                       ;t ;store link to old head of free list in the deleted node 
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
; find node b contains data looking for
; returns index of node in a register or null
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


