with Ada.Directories;

package body Files.Descriptor_Streams is

   use type Ada.Streams.Stream_Element_Offset;

   overriding procedure Read
     (Stream : in out Output_Stream;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset)
   is
      pragma Unreferenced (Stream, Item, Last);
   begin
      raise Program_Error;
   end Read;

   --  Write all of Item to the descriptor.
   procedure Write_Through
     (Stream : Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array)
   is
      Next    : Ada.Streams.Stream_Element_Offset := Item'First;
      Written : Integer;
   begin
      while Next <= Item'Last loop
         Written := GNAT.OS_Lib.Write
           (Stream.Descriptor, Item (Next)'Address,
            Integer (Item'Last - Next + 1));
         if Written <= 0 then
            raise Ada.Directories.Use_Error;
         end if;
         Next := Next + Ada.Streams.Stream_Element_Offset (Written);
      end loop;
   end Write_Through;

   procedure Flush (Stream : in out Output_Stream) is
   begin
      if Stream.Pending > 0 then
         Write_Through (Stream, Stream.Block (1 .. Stream.Pending));
         Stream.Pending := 0;
      end if;
   end Flush;

   overriding procedure Write
     (Stream : in out Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array)
   is
   begin
      if Item'Length > Block_Size - Stream.Pending then
         Flush (Stream);
      end if;
      if Item'Length >= Block_Size then
         Write_Through (Stream, Item);
      else
         Stream.Block (Stream.Pending + 1 .. Stream.Pending + Item'Length) := Item;
         Stream.Pending := Stream.Pending + Item'Length;
      end if;
   end Write;

end Files.Descriptor_Streams;
