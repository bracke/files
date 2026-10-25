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

   overriding procedure Write
     (Stream : in out Output_Stream;
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
   end Write;

end Files.Descriptor_Streams;
