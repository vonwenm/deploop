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

# == deployfacts.rb
#
# This file contains the Dice class definition and it runs
# some simple test code on a 16 sided dice.  A 20 dice
# roll fight again the COMPUTER who always rolls 10s!
#
# == Contact
#
# Author::  Javi Roman <javiroman@redoop.org>
# Website:: https://github.com/deploop/deploop
# Date:: 17-06-2014 

require 'rubygems'
require 'json'
require 'pp'
require 'net/ping'

require_relative '../lib/marionette'
require_relative '../lib/outputhandler'

module DeployFacts
  # Multi-sided dice class.  The number of sides is determined
  # in the constructor, or later on by accessing the _sides_
  # attribute.
  #
  # == Summary
  #  
  # A #single_roll returns a single integer from 1 to the
  # number of sides, _inclusive_.  However, if you want to
  # roll multiple times you can can use the #roll method,
  # specifying the number of rolls you want, and you will
  # get an Array with the values of all the rolls!
  # 
  # == Example
  # 
  #     dice = Dice.new(8)   # An eight sided dice
  #     four = dice.roll(4)  # An Array containing 4 rolls
  #     sum  = four.inject(0) { |mem,i| mem+i } # Sum of rolls
  # 
  class FactsDeployer
    def initialize(opt)
      @opt = opt
      @collections = ['production', 'preproduction', 'test']
      @categories = ['batch', 'bus', 'speed', 'serving']
      @roles_batch = ['nn1', 'nn2', 'rm', 'dn']
      @roles_speed = ['master', 'worker']
      @roles_bus = ['worker']
      @roles_serving = ['master', 'worker']
      @parsed_obj = nil

      @mchandler = Marionette::MCHandler.new 
      @outputHandler = OutputModule::OutputHandler.new opt.output

      # host = {'mncars001' => 
      #           {deploop_collection:'production', deploop_category:'batch',
      #            deploop_role:'nn1',deploop_entity:'flume'}, 
      #         'mncars002' => 
      #           {deploop_collection:'production', deploop_category:'batch',
      #            deploop_role:'nn2',deploop_entity:'flume'}, 
      #         }
      #
      # host['mncars003'] = {:a=>"new", :b=>"value"}
      @host_facts = Hash.new
    end

    # ==== Summary
    #
    # This method is used for check the JSON schema 
    # integrity, the syntax integrity and the cluster
    # logical organization. For example, you can not
    # deploy a Hadoop cluster without a NameNode node
    # in the JSON schema.
    #
    # ==== Attributes
    #
    # * +json+ - JSON file describing the cluster schema
    #
    # ==== Returns
    #  
    # ==== Examples
    #
    def checkJSON(json)
      # FIXME: logical check of cluster pending
      jsonObj = File.read(json)
      begin
          @parsed_obj = JSON.parse(jsonObj)
      rescue JSON::ParserError => e
        puts "ERROR: JSON file parsing error"
        exit
      end
    end # class FactsDeployer

    def create_facts(collection, category, show)
      case category
      when 'batch'
        $roles = @roles_batch
      when 'speed'
        $roles = @roles_speed
      when 'bus'
        $roles = @roles_bus
      else
        $roles = @roles_serving
      end

      $roles.each do |r|
        case r
        when 'dn', 'worker'
          @parsed_obj[collection][category][r].each do |w|
              $hostname=w['hostname']
              $entities=w['entity']

              @host_facts[$hostname] = 
                { 'deploop_collection' => collection, 
                  'deploop_category' => category,
                  'deploop_role' => r,
                  'deploop_entity' => $entities }

              if show
                print "#{$hostname}: deploop_collection=#{collection} "
                print "deploop_category=#{category} deploop_role=#{r} deploop_entity="
                $entities.each do |e|
                  print e + " "
                end
                puts ""
              end
           end
        else
            $hostname=@parsed_obj[collection][category][r]["hostname"]
            $entities=@parsed_obj[collection][category][r]["entity"]

            @host_facts[$hostname] = 
                { 'deploop_collection' => collection, 
                  'deploop_category' => category,
                  'deploop_role' => r,
                  'deploop_entity' => $entities }

            if show
              print "#{$hostname}: deploop_collection=#{collection} "
              print "deploop_category=#{category} deploop_role=#{r} deploop_entity="
              $entities.each do |e|
                print e + " "
              end
              puts ""
            end
        end
      end
    end

    def createFactsHash(json, show)
      checkJSON(json)
      @collections.each do |a|
        if @parsed_obj[a]
          @categories.each do |b|
            if @parsed_obj['production'][b]
              create_facts 'production',b, show
            end
          end
        end
      end
      if !show
        deployFacts
      end
    end

    def deployFacts
      @opt.deploy.each do |d|
        case d
        when 'batch'
          deployFactsLayer 'batch'
        when 'bus'
          deployFactsLayer 'bus'
        when 'speed'
          deployFactsLayer 'speed'
        when 'serving'
          deployFactsLayer 'serving'
        end
      end
    end 

    # ==== Summary
    #
    # This method exit the cli if any host of the layer
    # is not Deploop enabled. The program continue before the call if
    # the hosts are enabled.
    #
    # ==== Attributes
    #
    # * +layer+ - The cluster layer
    #
    def checkHosts(layer)
      @host_facts.each do |f|
        if f[1]['deploop_category'] == layer
          if !Net::Ping::TCP.new(f[0]).ping?
            msg = "ERROR: host \'#{f[0]}\' is unreachable. Aboring."
            @outputHandler.msgError msg
          end
          result = @mchandler.checkIfUp f[0]
          if result.empty?
            msg = "ERROR: host \'#{f[0]}\' is not Deploop enabled, fix this. Aborting."
            @outputHandler.msgError msg
          end
        end
      end
      msg = "The layer \'#{layer}\' has all host Deploop enabled"
      @outputHandler.msgOutput msg
    end
    
    def deployFactsLayer(layer)
      deploop_facts = ['deploop_collection',
                      'deploop_category',
                      'deploop_role',
                      'deploop_entity']
      checkHosts layer
      @host_facts.each do |f|
        if f[1]['deploop_category'] == layer
          @mchandler.deployEnv f[0], f[1]['deploop_collection']
          deploop_facts.each do |d|
            if d == 'deploop_entity'
              value = f[1][d].join(" ")
            else
              value = f[1][d]
            end
            puts f[0] + " " + d.split("_")[1] + " " + value
            @mchandler.deployFact f[0], d.split("_")[1], value
          end
        end
      end
    end

  end
end



