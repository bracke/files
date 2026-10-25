with Ada.Streams;

with GNAT.OS_Lib;

--  Write-only Ada stream over an open operating-system file descriptor, for
--  the job, copy and history journals that encode records with 'Output.
package Files.Descriptor_Streams is

   --  Stream that writes every element to Descriptor. The stream neither
   --  opens nor closes the descriptor; its owner does both.
   type Output_Stream is new Ada.Streams.Root_Stream_Type with record
      Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   end record;

   --  An output stream cannot be read.
   --
   --  @param Stream The stream.
   --  @param Item Unused.
   --  @param Last Unused.
   --  @raise Program_Error Always.
   overriding procedure Read
     (Stream : in out Output_Stream;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset);

   --  Write all of Item to the descriptor, continuing after short writes.
   --
   --  @param Stream The stream whose descriptor receives the bytes.
   --  @param Item Bytes to write.
   --  @raise Ada.Directories.Use_Error When a write fails or makes no progress.
   overriding procedure Write
     (Stream : in out Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array);

end Files.Descriptor_Streams;
