# vim: autoindent tabstop=2 shiftwidth=2 expandtab softtabstop=2 filetype=ruby
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
# Author::  Javi Roman <javiroman@redoop.org>
# Website:: http://www.redoop.org

module OutputModule
  class OutputHandler
    def initialize(output)
      @jsoned = output
    end

    def msgError(msg)
      if @jsoned
        jerror = {:error => true, :why => msg}
        puts JSON.generate jerror
        JSON.generate jerror
      else
        puts "\n" + msg
      end
      exit
    end

    def msgOutput(msg)
      if @jsoned
        jerror = {:error => false, :why => msg}
        puts JSON.generate jerror
        JSON.generate jerror
      else
        puts msg
      end
    end
  end # class OutputHandler
end



