class Memory
  attr_accessor :time_to_process
  def initialize size_in_bytes, random=false
    @data=Array.new(size_in_bytes){0}
    if random
      @data=Array.new(size_in_bytes){rand(256)}
    else
      @data=Array.new(size_in_bytes){0}
    end
    @time_to_process=10
  end

  def read addr
    @data[addr]
  end

  def write addr,data
    @data[addr]=data & 0xff
  end
end

class Line
  attr_accessor :valid,:tag,:bytes
  def initialize nb_bytes
    @nb_bytes=nb_bytes
    @valid=false
    @tag=nil
    @bytes=Array.new(nb_bytes){0}
  end

  def read byte_id
    if byte_id >= @nb_bytes
      raise "ERROR : max number of bytes per line is #{@nb_bytes}. Asked byte #{byte_id}"
    end
    @bytes[byte_id]
  end

  def write byte_id,byte
    @bytes[byte_id]=byte
  end
end

class DirectMappedCache

  attr_accessor :time_to_process

  def initialize nb_lines,nb_bytes
    @nb_lines,@nb_bytes=nb_lines,nb_bytes
    @lines=Array.new(nb_lines){Line.new(nb_bytes)}
    @nb_bits_offset=@nb_bytes.bit_length-1
    @nb_bits_index =@nb_lines.bit_length-1 # ex : nb_lines=8 =>nb_bits_index=3
    @index_mask=(2**@nb_bits_index-1) << @nb_bits_offset
    @offset_mask=2**@nb_bits_offset-1
  end

  def access_to memory
    @mem=memory
  end

  def print_status hit_of_miss,addr
    puts "cache #{hit_of_miss} at 0x#{addr.to_s(16)}"
  end

  def read addr
    index=(addr & @index_mask) >> @nb_bits_offset
    offset=addr & @offset_mask
    line=@lines[index]
    if line.valid
      if line.tag==addr_tag
        print_status("hit",addr)
        @time_to_process=1
      else
        print_status("miss",addr)
        load_line(addr,index)
      end
    else
      print_status("miss",addr)
      load_line(addr,index)
    end
    return @lines[index].bytes[offset]
  end

  #=============================================================================
  # Pour une adresse demandée A, le bloc chargé correspond à toutes les adresses alignées
  # sur la taille du bloc qui contiennent A. On oublie donc les bits d'offset :
  #=============================================================================
  def load_line addr,index
    puts "reloading line at index #{index}"
    base_addr=addr & ~@offset_mask # ~ = compl. à 1
    @nb_bytes.times do |byte_id| #physically, via bus burst.
      line=@lines[index]
      line.bytes[byte_id]=@mem.read(addr+byte_id)
      line.valid=true
    end
    @time_to_process=10
  end

  #=============================================================================
  # WARNING : ici simple politique naive de Write-through :
  # Toute écriture met à jour à la fois le cache ET la mémoire principale.
  # Ceci dégrade fortement la performance.
  # TODO : politique write-back.
  #=============================================================================
  def write addr,data
    byte=data & 0xff # le masque assure que la data écrite est un octet
    index_mask=(2**@nb_bits_index-1) << @nb_bits_offset
    addr_line=(addr & index_mask) >> @nb_bits_offset
    offset=addr & @offset_mask
    @lines[addr_line].bytes[offset]=byte
    @mem.write(addr,byte) # write-through le masque assure écriture d'un octet seulement
    @time_to_process=200 # !!!
  end
end

class Program

  def access_to memory
    @mem=memory
  end

  # ici il faudrait concevoir un générateur d'adresse semi-aléatoire
  # qui représente le comportement de programmes séquentiels (avec quelques sauts etc)
  def run
    write 0x0,142
    write 0x1,243
    write 0x2,144
    write 0x3,145
    write 0x4,156
    write 0x5,157
    read 0x0
    read 0x1
    read 0x2
    read 0x3
    read 0x4
    read 0x5
  end

  def read addr
    data=@mem.read(addr)
    puts "read 0x#{addr.to_s(16)} -> 0x#{data.to_s(16)}"
  end

  def write addr,data
    puts "write 0x#{addr.to_s(16)} 0x#{data.to_s(16)}"
    @mem.write(addr,data)
  end
end

ram=Memory.new(1024,random=true)
cache=DirectMappedCache.new(8,4)
cache.access_to ram
prog=Program.new
prog.access_to cache
prog.run
