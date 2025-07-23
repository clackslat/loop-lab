#!/usr/bin/env bb
;; =============================================================================
;; External Resources Cache Utility
;; =============================================================================
;; Purpose:
;;   Simple Babashka script to read external_resources.edn and provide 
;;   cache-related functions for the build system.
;;
;; Usage:
;;   ./external_resources.bb cache-location <arch> <resource-type>
;;   ./external_resources.bb source-url <arch> <resource-type>
;; =============================================================================

(ns docker.external-resources
  (:require [clojure.edn :as edn]
            [clojure.string :as str]))

;; =============================================================================
;; Configuration Loading
;; =============================================================================

(def config-file 
  (let [script-dir (-> (System/getProperty "babashka.file")
                       (or *file*)
                       java.io.File.
                       .getParent)]
    (str script-dir "/external_resources.edn")))

(defn load-config []
  (try
    (edn/read-string (slurp config-file))
    (catch Exception e
      (binding [*out* *err*]
        (println "Error reading config file:" config-file)
        (println "Error:" (.getMessage e)))
      (System/exit 1))))

;; =============================================================================
;; Cache Functions
;; =============================================================================

(defn find-resource 
  "Find resource for given architecture and type (boot or os)"
  [config arch resource-type]
  (let [arch-config (get config (keyword arch))]
    (when arch-config
      (let [type-config (get arch-config (keyword resource-type))]
        (when type-config
          (let [resource-group (if (= resource-type "boot") 
                                 (:shell type-config)
                                 type-config)]
            (when resource-group
              ;; Get the first resource value (the actual resource data)
              (first (vals resource-group)))))))))

(defn cache-location
  "Get cache location for architecture and resource type"
  [arch resource-type]
  (let [config (load-config)
        resource (find-resource config arch resource-type)]
    (when resource
      (get-in resource [:cache :path-to-initial]))))

(defn source-url
  "Get source URL for architecture and resource type"
  [arch resource-type]
  (let [config (load-config)
        resource (find-resource config arch resource-type)]
    (when resource
      (get-in resource [:source :url]))))

(defn docker-build-args
  "Generate Docker build arguments for a given architecture"
  [arch]
  (let [config (load-config)
        boot-resource (find-resource config arch "boot")
        os-resource (find-resource config arch "os")
        boot-arch (when boot-resource (get-in boot-resource [:meta :arch-name]))
        os-arch (when os-resource (get-in os-resource [:meta :arch-name]))]
    (when (and boot-arch os-arch)
      (str "--build-arg ARCH=" arch " "
           "--build-arg BOOT_ARCH=" boot-arch " "
           "--build-arg OS_ARCH=" os-arch))))

(defn image-path
  "Generate image path for a given architecture"
  [arch]
  (let [config (load-config)
        build-config (:build config)
        output-dir (:output-dir build-config)
        template (:image-name-template build-config)]
    (when (and output-dir template)
      (str output-dir "/" (str/replace template "{arch}" arch)))))

(defn image-size
  "Get image size from configuration"
  []
  (let [config (load-config)
        build-config (:build config)]
    (:image-size build-config)))

;; =============================================================================
;; Main CLI Interface
;; =============================================================================

(defn main [& args]
  (case (first args)
    "cache-location" 
    (if-let [result (cache-location (second args) (nth args 2))]
      (println result)
      (do
        (binding [*out* *err*]
          (println "Error: Cache location not found for" (second args) (nth args 2)))
        (System/exit 1)))
    
    "source-url"
    (if-let [result (source-url (second args) (nth args 2))]
      (println result)
      (do
        (binding [*out* *err*]
          (println "Error: Source URL not found for" (second args) (nth args 2)))
        (System/exit 1)))
    
    "docker-build-args"
    (if-let [result (docker-build-args (second args))]
      (println result)
      (do
        (binding [*out* *err*]
          (println "Error: Could not generate Docker build args for" (second args)))
        (System/exit 1)))
    
    "image-path"
    (if-let [result (image-path (second args))]
      (println result)
      (do
        (binding [*out* *err*]
          (println "Error: Could not generate image path for" (second args)))
        (System/exit 1)))
    
    "image-size"
    (if-let [result (image-size)]
      (println result)
      (do
        (binding [*out* *err*]
          (println "Error: Could not get image size from configuration"))
        (System/exit 1)))
    
    ;; Default help
    (do
      (println "Cache Utility Commands:")
      (println "  cache-location <arch> <type>     # Get cache file path")
      (println "  source-url <arch> <type>         # Get source download URL")
      (println "  docker-build-args <arch>         # Get Docker build arguments")
      (println "  image-path <arch>                # Get output image path")
      (println "  image-size                       # Get image size")
      (println "")
      (println "Arguments:")
      (println "  <arch>: x64, aarch64")
      (println "  <type>: boot, os")
      (println "")
      (println "Examples:")
      (println "  ./external_resources.bb cache-location x64 boot")
      (println "  ./external_resources.bb source-url x64 os")
      (println "  ./external_resources.bb docker-build-args x64")
      (println "  ./external_resources.bb image-path x64")
      (println "  ./external_resources.bb image-size")
      (System/exit 1))))

(when (= *file* (System/getProperty "babashka.file"))
  (apply main *command-line-args*))
