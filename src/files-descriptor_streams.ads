with Ada.Streams;

with GNAT.OS_Lib;

--  Write-only Ada stream over an open operating-system file descriptor, for
--  the job, copy and history journals that encode records with 'Output.
package Files.Descriptor_Streams is

   Block_Size : constant := 16 * 1024;

   --  Stream that writes its elements to Descriptor, gathered into blocks
   --  (records are encoded a field at a time). The stream neither opens nor
   --  closes the descriptor; its owner does both, and calls Flush first.
   type Output_Stream is new Ada.Streams.Root_Stream_Type with record
      Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Block      : Ada.Streams.Stream_Element_Array (1 .. Block_Size);
      Pending    : Ada.Streams.Stream_Element_Offset := 0;
   end record;

   --  Write the gathered bytes to the descriptor.
   --
   --  @param Stream The stream.
   --  @raise Ada.Directories.Use_Error When a write fails or makes no progress.
   procedure Flush (Stream : in out Output_Stream);

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

   --  Add Item to the stream; full blocks go to the descriptor, continuing
   --  after short writes.
   --
   --  @param Stream The stream whose descriptor receives the bytes.
   --  @param Item Bytes to write.
   --  @raise Ada.Directories.Use_Error When a write fails or makes no progress.
   overriding procedure Write
     (Stream : in out Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array);

end Files.Descriptor_Streams;
