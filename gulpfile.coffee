######################
# Requires
######################

del                      = require 'del'
fs                       = require 'fs'
babelify                 = require 'babelify'
babel                    = require 'babel-core'
browserify               = require 'browserify'
gulp                     = require 'gulp'
babel                    = require 'gulp-babel'
concat                   = require 'gulp-concat'
filter                   = require 'gulp-filter'
foreach                  = require 'gulp-foreach'
jade                     = require 'gulp-jade'
gulpIf                   = require 'gulp-if'
imagemin                 = require 'gulp-imagemin'
include                  = require 'gulp-include'
postcss                  = require 'gulp-postcss'
replace                  = require 'gulp-replace'
sourcemaps               = require 'gulp-sourcemaps'
uglify                   = require 'gulp-uglify'
gutil                    = require 'gulp-util'
rsync                    = require 'gulp-rsync'
gzip                     = require 'gulp-gzip'
cssnext                  = require 'cssnext'
lost                     = require 'lost'
bower                    = require 'main-bower-files'
postcsscenter            = require 'postcss-center'
postcssfocus             = require 'postcss-focus'
postcssfor               = require 'postcss-for'
postcssmixins            = require 'postcss-mixins'
postcssnested            = require 'postcss-nested'
postcsspxtorem           = require 'postcss-pxtorem'
rucksack                 = require 'rucksack-css'
browsersync              = require 'browser-sync'
buffer                   = require 'vinyl-buffer'
source                   = require 'vinyl-source-stream'
fatalLevel               = require('yargs').argv.fatal


deleteFolderRecursive = (path) ->
  if fs.existsSync(path)
    fs.readdirSync(path).forEach (file,index) ->
      curPath = path + "/" + file
      if fs.lstatSync(curPath).isDirectory()
        deleteFolderRecursive(curPath)
      else
        fs.unlinkSync(curPath)
    fs.rmdirSync(path)


####################
# Base Paths
####################

paths =
  base:
    root : ''
    src  : './src/'
    dist : './dist/'
    tmp  : './tmp/'

paths.src =
  css    : paths.base.src + 'assets/css'
  fonts  : paths.base.src + 'assets/fonts'
  js     : paths.base.src + 'assets/js'
  images : paths.base.src + 'assets/images'
  html   : paths.base.src + 'html'

paths.dist =
  css    : paths.base.dist + 'assets/css'
  fonts  : paths.base.dist + 'assets/fonts'
  js     : paths.base.dist + 'assets/js'
  images : paths.base.dist + 'assets/images'
  html   : paths.base.dist + ''




####################
# Error Handling (ref. https://gist.github.com/noahmiller/61699ad1b0a7cc65ae2d)
####################

watching = false

# Command line option:
#  --fatal=[warning|error|off]
ERROR_LEVELS = ['error', 'warning']

# Return true if the given level is equal to or more severe than
# the configured fatality error level.
# If the fatalLevel is 'off', then this will always return false.
# Defaults the fatalLevel to 'error'.
isFatal = (level) ->
  ERROR_LEVELS.indexOf(level) <= ERROR_LEVELS.indexOf(fatalLevel || 'error')

# Handle an error based on its severity level.
# Log all levels, and exit the process for fatal levels.
# ref. http://stackoverflow.com/questions/21602332/catching-gulp-mocha-errors#answers
handleError = (level, error) ->
  gutil.log(error.message)
  # if isFatal(level)
  #   process.exit(1)
  if watching
    this.emit('end')
  else
    process.exit(1)

# Convenience handler for error-level errors.
onError = (error) -> handleError.call(this, 'error', error)
# Convenience handler for warning-level errors.
onWarning = (error) -> handleError.call(this, 'warning', error)




######################
# Tasks
######################




gulp.task 'html', ->
  gulp.src "#{paths.src.html}/**/[^_]*.jade"
    .pipe jade()
    .on('error', onError)
    .pipe gulp.dest(paths.dist.html)
    .on('error', onError)



gulp.task 'css', ->
  postCSSProcessors = [
    cssnext               compress: { browsers: ['last 1 version'] },
                          autoprefixer: { browsers: ['last 1 version'] },
                          import: { from: "#{paths.src.css}/app.css" }
    rucksack
    postcssfor
    postcssmixins
    postcssnested
    postcssfocus
    postcsscenter
    postcsspxtorem
    lost
  ]

  gulp.src "#{paths.src.css}/**/[^_]*.{css,scss}"
    .pipe concat('app.css')
    .pipe sourcemaps.init()
      .pipe postcss(postCSSProcessors).on('error', onError)
    .pipe sourcemaps.write('maps')
    .pipe gulp.dest(paths.dist.css)
    .on('error', onError)

  gulp.src bower()
    .pipe filter('*.css')
    .pipe gulp.dest(paths.dist.css)
    .on('error', onError)




gulp.task 'fonts', ->
  gulp.src "#{paths.src.fonts}/**/*"
    .pipe gulp.dest(paths.dist.fonts)




gulp.task 'js', ->

  browserify paths.src.js + '/app.js', { debug: true }
    .transform babelify
    .bundle()
    .on 'error', gutil.log.bind(gutil, 'Browserify Error')
    .pipe source('app.js')
    .pipe buffer()
    .pipe sourcemaps.init({ loadMaps: true })
    .pipe uglify({ mangle: true }).on('error', onError)
    .pipe sourcemaps.write('maps')
    .pipe gulp.dest(paths.dist.js)
    .on 'error', onError

  # Copy files as-is from the bower packages. Refer to bower.json.
  gulp.src bower()
    .pipe filter('*.{js,map}')
    .pipe gulp.dest(paths.dist.js)
    .on('error', onError)




gulp.task 'images', ->
  gulp.src("#{paths.src.images}/**/*.{gif,jpg,png}")
    .pipe gulp.dest(paths.dist.images)




gulp.task 'clean', ->
  deleteFolderRecursive(paths.base.dist)
  deleteFolderRecursive(paths.base.tmp)




gulp.task 'build', ['html', 'css', 'fonts', 'js', 'images']




gulp.task 'refresh', ['clean', 'build']




gulp.task 'browsersync', ->
  browsersync.use
    plugin: ->,
    hooks:
      'client:js': fs.readFileSync("./lib/closer.js", "utf-8")
  browsersync.init [paths.dist.html, paths.dist.css, paths.dist.js],
    server:
      baseDir: paths.dist.html




gulp.task 'watch', ['browsersync'], ->
  watching = true
  gulp.watch ["#{paths.src.html}/**/*.jade", "#{paths.src.images}/**/*.svg"], ['html']
  gulp.watch "#{paths.src.mail}/**/*.jade", ['email-template']
  gulp.watch "#{paths.src.css}/**/*", ['css']
  gulp.watch "#{paths.src.fonts}/**/*", ['fonts']
  gulp.watch "#{paths.src.js}/**/*.{js}", ['js']
  gulp.watch "#{paths.src.images}/**/*.{gif,jpg,png}", ['images']



gulp.task 'default', ['refresh', 'watch']
